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
/// is weird and I fear needs actual sqlite3 admin knowledge to understand).
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

    struct Key: Hashable {
        let text: String
        let language: DefLanguage?
    }

    // ok i'm too dumb to write this as one hash...
    private(set) var cacheHits = [Key:Autolink]()
    private(set) var cacheMisses = Set<Key>()

    func autolink(text: String, language: DefLanguage? = nil) -> Autolink? {
        let key = Key(text: text, language: language)
        if let cachedResult = cacheHits[key] {
            Stats.inc(.autolinkAppleCacheHitHit)
            return cachedResult
        }
        if cacheMisses.contains(key) {
            Stats.inc(.autolinkAppleCacheHitMiss)
            return nil
        }
        if let newResult = doAutolink(text: text, language: language) {
            cacheHits[key] = newResult
            return newResult
        }
        cacheMisses.insert(key)
        return nil
    }

    static let APPLE_DOCS_BASE_URL = "https://developer.apple.com/documentation/"

    func doAutolink(text: String, language: DefLanguage?) -> Autolink? {
        guard !disableOpt.value,
            let db = db else {
            return nil
        }

        do {
            // Massage the autolink text into query strings to persuade the db
            let refPath = AppleDocsDb.RefPath(autolinkText: text, language: language)

            func findBestRow() throws -> AppleDocsDb.Row? {
                if let row = try db.query(pathLike: refPath.queryPathInModule,
                                          language: refPath.language) {
                    return row
                }
                guard let asModulePath = refPath.queryPathAsModule else {
                    return nil
                }
                return try db.query(pathLike: asModulePath,
                                    language: refPath.language)
            }

            guard let row = try findBestRow(), refPath.validate(row: row) else {
                logDebug("AutolinkApple: failed to match '\(text)'.")
                Stats.inc(.autolinkAppleFailure)
                return nil
            }
            logDebug("AutolinkApple: matched \(text) to \(row.referencePath)")
            Stats.inc(.autolinkAppleSuccess)

            // Try to find the same topic in the other language.
            let otherRow = try db.query(language: row.language.otherLanguage,
                                        topicId: row.topicId)

            // Finally generate the autolink content
            let secondaryHtml = otherRow.flatMap { $0.htmlLink(text, isSecondary: true) } ?? ""
            return Autolink(url: row.urlString, html: row.htmlLink(text) + secondaryHtml)
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

    /// Return the best fitting row for the path and optionally language.
    func query(pathLike path: String, language: DefLanguage?) throws -> Row? {
        let baseQuery = map.select(topicId, sourceLanguage, referencePath)
            .filter(referencePath.like(path))

        let langQuery = language.flatMap {
            baseQuery.filter(sourceLanguage == $0.appleId)
        } ?? baseQuery

        return try doQuery(langQuery)
    }

    /// Return the best-fitting row for the language & topic ID.
    func query(language: DefLanguage, topicId: Int64) throws -> Row? {
        try doQuery(map.select(self.topicId, sourceLanguage, referencePath)
            .filter(self.sourceLanguage == language.appleId)
            .filter(self.topicId == topicId))
    }

    /// Exec a query, adding logic to return the matching row with the shortest ref_path.
    private func doQuery(_ query: Table) throws -> Row? {
        try db.prepare(query
            .order(self.referencePath.length)
            .filter(self.sourceLanguage < 2)
            .limit(1)
        ).compactMap { dbRow -> Row? in
            guard let language = DefLanguage(appleId: dbRow[sourceLanguage]) else {
                return nil
            }
            return Row(topicId: dbRow[topicId],
                       language: language,
                       referencePath: dbRow[referencePath])
        }.first
    }

    // MARK: RefPath mangling and guessing

    struct RefPath {
        let pieces: [String]
        let language: DefLanguage?
        
        /// Decompose an autolink-syntax identifier into pieces relevant to the DB and a hint
        /// to what language it is.
        init(autolinkText: String, language: DefLanguage?) {
            if autolinkText.contains("(") {
                // Swift function, only the part of the name before the parens matter
                self.pieces = autolinkText.re_sub(#"\(.*$"#, with: "").strsplit(".")
                self.language = .swift
            } else if autolinkText.isObjCClassMethodName {
                // ObjC method.  Want classname.firstpartofname - discard +- and the rest of the name
                let firstPieces = autolinkText.hierarchical.re_split("[.+-:]")
                self.pieces = Array(firstPieces.prefix(2))
                self.language = .objc
            } else {
                // Some dot-separated identifier
                self.pieces = autolinkText.strsplit(".")
                self.language = language
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

        /// Validate a query result -- removing accidental matches of stuff that
        /// really is not intended to link out.
        /// eg. stop `after` => `coretext/ctrubyposition/after`
        /// (allow one extra component for a module name)
        func validate(row: Row) -> Bool {
            row.referencePath.components(separatedBy: "/").count <= pieces.count + 1
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
