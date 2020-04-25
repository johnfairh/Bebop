//
//  FormatAutolinkApple.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SQLite

/// Autolinking to reference docs on apple.com.
///
/// Based on jazzy prototype work by github/galli-leo and me of some years ago.
///
/// Very approximate lookups based on portions of names - there could be a better way to do this,
/// covers 90+% of uses fairly efficiently (though the DB access can go v. slow sometimes which
/// is weird).
///
/// This is all [ab]use of undocumented stuff that could break/vanish at any Xcode release...
///
final class FormatAutolinkApple: Configurable {
    let disableOpt = BoolOpt(l: "no-apple-autolink")
    let xcodePathOpt = PathOpt(l: "apple-autolink-xcode-path").help("XCODEAPPPATH")

    init(config: Config) {
        config.register(self)
    }

    func checkOptions() throws {
        try xcodePathOpt.checkIsDirectory()
        if let xcodePathURL = xcodePathOpt.value,
            !xcodePathURL.lastPathComponent.hasSuffix(".app") {
            throw OptionsError(.localized(.errCfgXcodepath, xcodePathURL.path))
        }
    }

    // MARK: Setup

    static let CONTENTS_MAP_DB_PATH =
        "SharedFrameworks/DNTDocumentationSupport.framework/Resources/external/map.db"

    var databaseURL: URL? {
        if let xcodePathURL = xcodePathOpt.value {
            return xcodePathURL
                .appendingPathComponent("Contents")
                .appendingPathComponent(Self.CONTENTS_MAP_DB_PATH)
        }
        #if os(macOS)
        let xcodeSelectResults = Exec.run("/usr/bin/env", "xcode-select", "-p")
        guard let developerPath = xcodeSelectResults.successString?.trimmingCharacters(in: .newlines) else {
            logWarning(.localized(.wrnAppleautoXcode, xcodeSelectResults.failureReport))
            return nil
        }
        return URL(fileURLWithPath: developerPath)
            .deletingLastPathComponent()
            .appendingPathComponent(Self.CONTENTS_MAP_DB_PATH)
        #else
        logDebug("FormatAutolinkApple: Not macOS, --apple-autolink-xcode-path not set, not doing it.")
        return nil
        #endif
    }

    private(set) lazy var db: AppleDocsDb? = {
        databaseURL.flatMap { dbURL in
            do {
                return try AppleDocsDb(url: dbURL)
            } catch {
                logWarning(.localized(.wrnAppleautoDbo, dbURL.path, error))
                return nil
            }
        }
    }()

    // MARK: Query

    // Cache the results to avoid continuously hitting the DB for Bool etc....

    // ok i'm too dumb to write this as one hash...
    private(set) var cacheHits = [String:Autolink]()
    private(set) var cacheMisses = Set<String>()

    func autolink(text: String) -> Autolink? {
        if let cachedResult = cacheHits[text] {
            Stats.inc(.autolinkAppleCacheHitHit)
            return cachedResult
        }
        if cacheMisses.contains(text) {
            Stats.inc(.autolinkAppleCacheHitMiss)
            return nil
        }
        if let newResult = doAutolink(text: text) {
            cacheHits[text] = newResult
            return newResult
        }
        cacheMisses.insert(text)
        return nil
    }

    static let APPLE_DOCS_BASE_URL = "https://developer.apple.com/documentation/"

    func doAutolink(text: String) -> Autolink? {
        guard !disableOpt.value,
            let db = db else {
            return nil
        }

        do {
            // Massage the autolink text into query strings to persuade the db
            let refPath = AppleDocsDb.RefPath(autolinkText: text)
            var rows = try db.query(pathLike: refPath.queryPathInModule)
            if rows.isEmpty, let asModulePath = refPath.queryPathAsModule {
                rows = try db.query(pathLike: asModulePath)
            }

            rows = rows.sanitized(refPath: refPath)
            guard !rows.isEmpty else {
                logDebug("AutolinkApple: failed to match '\(text)'.")
                Stats.inc(.autolinkAppleFailure)
                return nil
            }
            logDebug("AutolinkApple: matched \(text) to \(rows.count) rows")
            Stats.inc(.autolinkAppleSuccess)

            // Guesstimatching means we can get all kinds of results.  Prefer the
            // shortest match - wildcards done least work.

            // Grab the first row of the right language if we guessed it from the text
            let bestRow = rows
                .first { row in
                    refPath.language.flatMap { $0 == row.language} ?? true
                } ?? rows[0]

            // Try to find the same topic in the other language - we may already have it
            // but if the names are different in objc/swift we need to hit the db again
            var otherRow = rows.first { $0.language == bestRow.language.otherLanguage }
            if otherRow == nil {
                otherRow = try db.query(language: bestRow.language.otherLanguage,
                                        topicId: bestRow.topicId)
                    .sanitized(refPath: refPath)
                    .first
            }
            // Finally generate the autolink content
            let secondaryHtml = otherRow.flatMap { $0.htmlLink(text, isSecondary: true) } ?? ""
            return Autolink(markdownURL: bestRow.urlString,
                            primaryURL: bestRow.urlString,
                            html: bestRow.htmlLink(text) + secondaryHtml)
        } catch {
            logWarning(.localized(.wrnAppleautoDbq, text, error))
        }
        return nil
    }
}

// MARK: DB access

final class AppleDocsDb {
    let db: Connection
    let map: Table
    let topicId: Expression<Int64>
    let sourceLanguage: Expression<Int64>
    let referencePath: Expression<String>

    init(url: URL) throws {
        db = try Connection(url.path, readonly: true)
        map = Table("map")
        topicId = Expression("topic_id")
        sourceLanguage = Expression("source_language")
        referencePath = Expression("reference_path")
    }

    struct Row {
        let topicId: Int64
        let language: DefLanguage
        let referencePath: String

        var urlString: String {
            FormatAutolinkApple.APPLE_DOCS_BASE_URL +
                referencePath +
                "?language=" +
                language.rawValue
        }

        func htmlLink(_ name: String, isSecondary: Bool = false) -> String {
            let classes = language.cssName + (isSecondary ? " j2-secondary" : "")
            return #"<a href="\#(urlString)" class="\#(classes)">\#(name.htmlEscaped)</a>"#
        }
    }

    /// select all where referencepath like path
    func query(pathLike path: String) throws -> [Row] {
        try doQuery(map.select(topicId, sourceLanguage, referencePath)
            .filter(referencePath.like(path)))
    }

    /// select all where source_language == language, topic_id == topic_id
    func query(language: DefLanguage, topicId: Int64) throws -> [Row] {
        try doQuery(map.select(self.topicId, sourceLanguage, referencePath)
            .filter(self.sourceLanguage == language.appleId)
            .filter(self.topicId == topicId))
    }

    /// Exec a query.  Filter out any javascript or whatever rows.
    private func doQuery(_ query: Table) throws -> [Row] {
        try db.prepare(query).compactMap { dbRow in
            guard let language = DefLanguage(appleId: dbRow[sourceLanguage]) else {
                return nil
            }
            return Row(topicId: dbRow[topicId],
                       language: language,
                       referencePath: dbRow[referencePath])
        }
    }

    // MARK: RefPath mangling and guessing

    struct RefPath {
        let pieces: [String]
        let language: DefLanguage?
        
        /// Decompose an autolink-syntax identifier into pieces relevant to the DB and a hint
        /// to what language it is.
        init(autolinkText: String) {
            if autolinkText.contains("(") {
                // Swift function, only the part of the name before the parens matter
                pieces = autolinkText.re_sub(#"\(.*$"#, with: "").strsplit(".")
                language = .swift
            } else if autolinkText.isObjCClassMethodName {
                // ObjC method.  Want classname.firstpartofname - discard +- and the rest of the name
                let firstPieces = autolinkText.hierarchical.re_split("[.+-:]")
                pieces = Array(firstPieces.prefix(2))
                language = .objc
            } else {
                // Some dot-separated identifier
                pieces = autolinkText.strsplit(".")
                language = nil
            }
        }

        /// If we're a leaf item iike a property, the final piece is prefixed by the topic-id
        /// and its name is truncated to 32 characters (bytes??)
        ///
        /// If the leaf item is a type then there's no topic-id or truncation,  So we
        /// do the best we can with wildcards.  Will break on types that share a 32-prefix
        /// but that's what they deserve.
        private var asFullQueryPath: String {
            let last = pieces.last
            let first = pieces.dropLast()
            return first.joined(separator: "/") +
                (last.flatMap { "/%\($0.prefix(32))%"} ?? "")
        }

        /// An SQL 'like' expression for the autolink text, assuming the user has omitted
        /// the autolink type's module name -- meaning we wildcard the module name.
        var queryPathInModule: String {
            if pieces.count == 1 {
                return "%/\(pieces[0])"
            }
            return "%/\(asFullQueryPath)"
        }

        /// An SQL 'like' expression for the autolink text, assuming it contains a module
        /// name.  If there's just one piece (no dots) in the autolink text then return nil -
        /// no chance of a match.
        var queryPathAsModule: String? {
            guard pieces.count > 1 else {
                return nil
            }
            return asFullQueryPath
        }
    }
}

extension Array where Element == AppleDocsDb.Row {
    /// Polish up the query results.
    /// 1 - remove accidental matches where we can spot them,
    ///   eg. stop `after` => `coretext/ctrubyposition/after`
    ///   (allow one extra component for a module name)
    /// 2 - order by refpath length, shortest first
    func sanitized(refPath: AppleDocsDb.RefPath) -> Self {
        filter { row in
            row.referencePath.components(separatedBy: "/").count <=
                (refPath.pieces.count + 1)
        }.sorted {
            $0.referencePath.count < $1.referencePath.count
        }
    }
}


// MARK: DefLanguage mapping

extension DefLanguage {
    init?(appleId: Int64) {
        switch appleId {
        case 0: self = .swift
        case 1: self = .objc
        default: return nil
        }
    }

    var appleId: Int64 {
        switch self {
        case .swift: return 0
        case .objc: return 1
        }
    }
}

private extension String {
    func strsplit(_ separator: Element) -> [String] {
        split(separator: separator).map(String.init)
    }
}
