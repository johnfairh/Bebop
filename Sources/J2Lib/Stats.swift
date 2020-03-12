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

    let published: Config.Published

    init(config: Config) {
        Self.db.reset()
        published = config.published
        config.register(self)
    }

    /// exposed just for testing really
    private(set) static var db = StatsDb()

    /// Shared API to increment a counter
    static func inc(_ counter: StatsDb.Counter) {
        db.inc(counter)
    }

    /// Shared API to register an undocumented def
    static func addUndocumented(item: DefItem) {
        db.addUndocumented(item: item)
    }

    /// Shared API to get at the coverage value
    static var coverage: Int {
        db.coverage
    }

    /// Report the counters for debug
    func debugReport() {
        Self.db.debugReport()
    }

    /// Report summary info to the user
    func printReport() {
        Self.db.coverageReport(aclExcludedNames: published.excludedAclList).forEach { logInfo($0 )}
    }

    /// Write out the accumulated stats to a file
    func createStatsFile(outputURL: URL) throws {
        let url = try chooseURL(docURL: outputURL, opt: outputStatsOpt, basename: "stats.json")
        try Self.db.buildStatsJSON().write(to: url)
    }

    /// Write out the undocumented report to a file - if there are any
    func createUndocumentedFile(outputURL: URL) throws {
        guard let undocJSON = try Self.db.buildUndocumentedJSON() else {
            logDebug("Stats: No undocumented defs, not writing undoc file.")
            return
        }
        let url = try chooseURL(docURL: outputURL, opt: outputUndocOpt, basename: "undocumented.json")
        try undocJSON.write(to: url)
    }

    private func chooseURL(docURL: URL, opt: PathOpt, basename: String) throws -> URL {
        let url: URL
        if let userURL = opt.value {
            logDebug("Stats: Using user URL for \(basename): \(userURL.path)")
            url = userURL
        } else {
            url = docURL.appendingPathComponent(basename)
            logDebug("Stats: Using docs URL for \(basename): \(url.path)")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        return url
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
        /// Defs with a guessed ACL (of `internal`)`
        case importGuessedAcl
        /// Defs merged as dup definitions
        case mergeDupUsr
        /// Defs with colliding USRs
        case mergeDupUsrMismatch
        /// Defs merged as default implementation
        case mergeDefaultImplementation
        /// Defs demoted to default implementation
        case mergeDemoteDefaultImplementation
        /// Defs excluded by filename
        case filterFilename
        /// Defs excluded by symbol name
        case filterSymbolName
        /// Defs excluded by :nodoc:
        case filterNoDoc
        /// Defs excluded by min-acl
        case filterMinAclExcluded
        /// Defs included by min-acl
        case filterMinAclIncluded
        /// Extensions excluded by being empty
        case filterUselessExtension
        /// Defs without documentation that should have them
        case missingDocumentation
        /// Defs with documentation that should have them
        case documentedDef
        /// Defs excluded because no docs and skip-undoc
        case filterSkipUndocumented
        /// Defs excluded because no docs, override, skip-undoc-override
        case filterSkipUndocOverride
        /// Defs whose inherited docs are ignored
        case filterIgnoreInheritedDocs
        /// Markdown chunks formatted
        case formatMarkdown
        /// Autolinks resolved to local docs in local scope
        case autolinkLocalLocalScope
        /// Autolinks resolved to local docs in global scope
        case autolinkLocalGlobalScope
        /// Autolink candidate resolved to self and ignored
        case autolinkSelfLink
        /// Autolink candidate not resolved
        case autolinkNotAutolinked
    }
    private var counters = [String : Int]()

    init() {
        reset()
    }

    mutating func inc(_ counter: Counter) {
        counters.reduceKey(counter.rawValue, 1, { $0 + 1})
    }

    subscript(counter: Counter) -> Int {
        get {
            counters[counter.rawValue]!
        }
    }

    func debugReport() {
        logDebug("Stats: counters:")
        counters.sorted(by: {l, r in l.key < r.key }).forEach { kv in
            logDebug("       \(kv.key) = \(kv.value)")
        }
    }

    var coverage: Int {
        let undocCount = self[.missingDocumentation]
        let docCount = self[.documentedDef]
        let total = docCount + undocCount
        guard total > 0 else { return 0 }
        return (100 * docCount) / total
    }

    func coverageReport(aclExcludedNames: String) -> [String] {
        var report = [String.localized(.msgCoverage, coverage,  self[.missingDocumentation])]
        let aclSkipped = self[.filterMinAclExcluded]
        if aclSkipped > 0 {
            report.append(.localized(.msgSwiftAcl, aclSkipped, aclExcludedNames))
        }
        return report
    }

    func buildStatsJSON() throws -> String {
        try JSON.encode(counters) + "\n"
    }

    private var undocumented = [DefItem.UndocInfo]()

    mutating func addUndocumented(item: DefItem) {
        undocumented.append(item.asUndocInfo)
        inc(.missingDocumentation)
    }

    func buildUndocumentedJSON() throws -> String? {
        guard !undocumented.isEmpty else {
            return nil
        }
        let undocs = undocumented.sorted(by: <)
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
