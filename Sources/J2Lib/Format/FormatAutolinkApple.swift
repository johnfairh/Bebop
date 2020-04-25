//
//  FormatAutolinkApple.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SQLite

final class FormatAutolinkApple: Configurable {
    let disableOpt = BoolOpt(l: "disable-apple-autolink")
    let xcodePathOpt = PathOpt(l: "apple-autolink-xcode-path").help("XCODEAPPPATH")

    init(config: Config) {
        config.register(self)
    }

    func checkOptions() throws {
        try xcodePathOpt.checkIsDirectory()
        if let xcodePathURL = xcodePathOpt.value,
            !xcodePathURL.lastPathComponent.hasSuffix(".app") {
            throw OptionsError("Value for --apple-autolink-xcode-path should be some Xcode.app: '\(xcodePathURL.path)'.")
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
            logWarning("Can't find current Xcode, not autolinking to Apple docs.\n\(xcodeSelectResults.failureReport)")
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
                logWarning("Can't open Apple docs DB \(dbURL.path): \(error).")
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
        guard !disableOpt.value else {
            return nil
        }

        guard let db = db else {
            return nil
        }

        do {
            let rows = try db.query(pathLike: "swift/string")
            guard let row = rows.first else {
                logDebug("AutolinkApple: No db match for '\(text)'.")
                return nil
            }
            let url = Self.APPLE_DOCS_BASE_URL +
                row.referencePath +
                "?language=" +
                row.language.rawValue
            return Autolink(markdownURL: url,
                            primaryURL: url,
                            html: #"<a href="\#(url)" class="\#(row.language.cssName)">\#(text.htmlEscaped)</a>"#)
        } catch {
            logDebug("AutolinkApple: DB error on query for \(text): \(error).")
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
    }

    /// select all where referencepath like path
    func query(pathLike path: String) throws -> [Row] {
        try doQuery(map.select(topicId, sourceLanguage, referencePath)
            .filter(referencePath.like(path)))
    }

    /// select all where source_language == language, topic_id == topic_id
    func query(language: DefLanguage, topicId: Int64) throws -> [Row] {
        try doQuery(map.select(topicId, sourceLanguage, referencePath)
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
