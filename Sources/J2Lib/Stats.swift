//
//  Stats.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Stats: Configurable {
    let outputStatsOpt = PathOpt(l: "output-stats").help("FILEPATH")
    let outputUndocOpt = PathOpt(l: "output-undocumented").help("FILEPATH")

    init(config: Config) {
        Stats.db.reset()
        config.register(self)
    }

    private static var db = StatsDb()

    /// Shared API to increment a counter
    static func inc(_ counter: StatsDb.Counter) {
        db.inc(counter)
    }

    /// Shared API to register an undocumented def
    static func addUndocumented(item: DefItem) {
        db.addUndocumented(item: item)
    }

    /// Report the counters for debug
    func debugReport() {
        Self.db.debugReport()
    }

    /// Write out the accumulated stats to a file
    func createStatsFile(outputURL: URL) throws {
        let url = chooseURL(docURL: outputURL, opt: outputStatsOpt, basename: "stats.json")
        try Self.db.buildStatsJSON().write(to: url)
    }

    /// Write out the undocumented report to a file - if there are any
    func createUndocumentedFile(outputURL: URL) throws {
        guard let undocJSON = try Self.db.buildUndocumentedJSON() else {
            logDebug("Stats: No undocumented defs, not writing undoc file.")
            return
        }
        let url = chooseURL(docURL: outputURL, opt: outputUndocOpt, basename: "undocumented.json")
        try undocJSON.write(to: url)
    }

    private func chooseURL(docURL: URL, opt: PathOpt, basename: String) -> URL {
        if let userURL = opt.value {
            logDebug("Stats: Using user URL for \(basename): \(userURL.path)")
            return userURL
        }
        let defaultURL = docURL.appendingPathComponent(basename)
        logDebug("Stats: Using docs URL for \(basename): \(defaultURL.path)")
        return defaultURL
    }
}

// MARK: Stats DB

/// The actual stats -- counters and a list of undocumented definitions
struct StatsDb {
    enum Counter: String, Encodable, CaseIterable {
        /// Defs successfully created from some input source
        case gatherDef
        /// Defs that failed to create from some input source
        case gatherFailure
        /// Markdown chunks processed for localization keys
        case gatherLocalizationKey
        /// Markdown localization successes
        case gatherLocalizationSuccess
        /// Markdown localization failures
        case gatherLocalizationFailure
        /// Defs rejected because of a missing root
        case importFailureNoRoot
        /// Defs rejected because of a definite compilation error
        case importFailureNoType
        /// Defs rejected because of usr, dup or compilation error
        case importFailureNoUsr
        /// Defs rejected because incomplete
        case importFailureIncomplete
        /// Defs not imported because excluded
        case importExcluded
        /// Defs merged as dup definitions
        case mergeDupUsr
        /// Defs with colliding USRs
        case mergeDupUsrMismatch
        /// Defs merged as default implementation
        case mergeDefaultImplementation
        /// Defs demoted to default implementation
        case mergeDemoteDefaultImplementation
        /// Markdown chunks formatted
        case formatMarkdown
    }
    private var counters = [String : Int]()

    mutating func inc(_ counter: Counter) {
        counters.reduceKey(counter.rawValue, 1, { $0 + 1})
    }

    func debugReport() {
        logDebug("Stats: counters:")
        counters.sorted(by: {l, r in l.key < r.key }).forEach { kv in
            logDebug("       \(kv.key) = \(kv.value)")
        }
    }

    func buildStatsJSON() throws -> String {
        try JSON.encode(counters) + "\n"
    }

    private var undocumented = [DefItem]()

    mutating func addUndocumented(item: DefItem) {
        undocumented.append(item)
    }

    func buildUndocumentedJSON() throws -> String? {
        guard !undocumented.isEmpty else {
            return nil
        }
        let undocs = undocumented
            .map { $0.asUndocInfo }
            .sorted(by: <)
        return try JSON.encode(undocs) + "\n"
    }

    mutating func reset() {
        Counter.allCases.forEach { counters[$0.rawValue] = 0 }
        undocumented = []
    }
}

fileprivate extension DefItem {
    /// Quick record for undocumented.json
    struct UndocInfo: Encodable, Comparable {
        let location: DefLocation
        let symbol: String
        let kind: String

        static func < (lhs: DefItem.UndocInfo, rhs: DefItem.UndocInfo) -> Bool {
            lhs.location < rhs.location
        }
    }

    var asUndocInfo: UndocInfo {
        UndocInfo(location: location,
                  symbol: name,
                  kind: defKind.key)
    }
}
