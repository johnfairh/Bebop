//
//  Stats.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SortedArray

public final class Stats: Configurable {
    private let outputStatsOpt = PathOpt(l: "output-stats").help("FILEPATH")
    private let outputUndocOpt = PathOpt(l: "output-undocumented").help("FILEPATH")
    private let outputUnresolvedOpt = PathOpt(l: "output-unresolved").help("FILEPATH")

    private let published: Published

    public init(config: Config) {
        Self.db.reset()
        published = config.published
        config.register(self)
    }

    /// exposed just for testing really
    private(set) static nonisolated(unsafe) var db = StatsDb()

    /// Shared API to increment a counter
    static func inc(_ counter: StatsDb.Counter) {
        db.inc(counter)
    }

    /// Shared API to register an undocumented def
    static func addUndocumented(item: DefItem) {
        db.addUndocumented(item: item)
    }

    /// Shared API to register an unresolved link
    static func addUnresolved(name: String, context: String) {
        db.addUnresolved(name: name, context: context)
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
    public func printReport() {
        Self.db.coverageReport(aclExcludedNames: published.excludedACLs).forEach { logInfo($0 )}
    }

    /// Write out the accumulated stats to a file
    public func createStatsFile(outputURL: URL) throws {
        let url = try chooseURL(docURL: outputURL, opt: outputStatsOpt, basename: "stats.json")
        try Self.db.buildStatsJSON().write(to: url)
    }

    /// Write out the undocumented report to a file - if there are any
    public func createUndocumentedFile(outputURL: URL) throws {
        guard let undocJSON = try Self.db.buildUndocumentedJSON() else {
            logDebug("Stats: No undocumented defs, not writing undoc file.")
            return
        }
        let url = try chooseURL(docURL: outputURL, opt: outputUndocOpt, basename: "undocumented.json")
        try undocJSON.write(to: url)
    }

    /// Write out the unresolved report to a file
    public func createUnresolvedFile(outputURL: URL) throws {
        guard let unresolvedJSON = try Self.db.buildUnresolvedJSON() else {
            logDebug("Stats: No unresolved links, not writing unresolved file.")
            return
        }
        let url = try chooseURL(docURL: outputURL, opt: outputUnresolvedOpt, basename: "unresolved.json")
        try unresolvedJSON.write(to: url)
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
        /// Defs successfully reconstituted from JSON
        case gatherDefImport
        /// Defs that failed to create from some input source
        case gatherFailure
        /// Markdown chunks processed for localization keys
        case gatherLocalizationKey
        /// Markdown localization successes
        case gatherLocalizationSuccess
        /// Markdown localization failures
        case gatherLocalizationFailure
        /// ObjC decls matched to Swift decls
        case gatherSwiftToObjC
        /// XML doc comments parsed
        case gatherXMLDocCommentsParsed
        /// XML doc comments failed to parse
        case gatherXMLDocCommentsFailed
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
        /// Defs abandoned due to --hide-language
        case importFailureLanguage
        /// Defs abandoned due to --hide-language and no translation
        case importFailureLanguageKind
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
        /// Defs excluded by @_spi
        case filterSpi // Can't be `SPI` because then Linux sorts it differently!!
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
        /// Markdown chunks formatted
        case formatMarkdown
        /// Links rewritten to media
        case formatRewrittenMediaLinks
        /// Links rewritten to guides
        case formatRewrittenGuideLinks
        /// Links rewritten to the readme
        case formatRewrittenReadmeLinks
        /// Links that couldn't be rewritten
        case formatUnrewrittenLinks
        /// Mathematical expressions formatted
        case formatMathExpression
        /// Autolinks resolved to local docs in local scope
        case autolinkLocalLocalScope
        /// Autolinks resolved to local docs in nested scope
        case autolinkLocalNestedScope
        /// Autolinks resolved to local docs in global scope
        case autolinkLocalGlobalScope
        /// Autolink candidate resolved to self and ignored
        case autolinkSelfLink
        /// Autolink candidate not resolved to local docset
        case autolinkNotAutolinked
        /// Autolink to remote/apple docs resolved from cache
        case autolinkCacheHitHit
        /// Autolink to remote/apple docs failed from cache
        case autolinkCacheHitMiss
        /// Autolink to apple docs worked
        case autolinkAppleSuccess
        /// Autolink to apple docs failed
        case autolinkAppleFailure
        /// Autolink to remote by name
        case autolinkRemoteSuccess
        /// Autolink to remote by name with a module
        case autolinkRemoteSuccessModule
        /// Autolink to remote failed
        case autolinkRemoteFailure
        /// Autolink failed every which way we tried
        case autolinkUnresolved
        /// Custom abstracts applied to defs
        case customAbstractDef
        /// Custom abstracts applied to groups
        case customAbstractGroup
        /// Guides excluded from guides-by-kind
        case groupExcludedGuidesByKind
        /// Guides included in guides-by-kind
        case groupIncludedGuidesByKind
        /// Defs included in defs by-kind
        case groupIncludedDefsByKind
        /// Kind groups created
        case groupsByKind
        /// Custom groups decoded from config
        case groupCustomDecoded
        /// Custom defs decoded from config
        case groupCustomDefDecoded
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
        var report = [String]()
        let aclSkipped = self[.filterMinAclExcluded]
        if aclSkipped > 0 {
            report.append(.localized(.msgSwiftAcl, aclSkipped, aclExcludedNames))
        }
        let spiSkipped = self[.filterSpi]
        if spiSkipped > 0 {
            report.append(.localized(.msgSpiSkipped, spiSkipped))
        }
        report.append(.localized(.msgCoverage, coverage, self[.documentedDef], self[.missingDocumentation]))
        return report
    }

    func buildStatsJSON() throws -> String {
        try JSON.encode(counters) + "\n"
    }

    private var undocumented = SortedArray<DefItem.UndocInfo>()

    mutating func addUndocumented(item: DefItem) {
        undocumented.insert(item.asUndocInfo)
        inc(.missingDocumentation)
    }

    func buildUndocumentedJSON() throws -> String? {
        guard !undocumented.isEmpty else {
            return nil
        }
        return try JSON.encode(Array(undocumented)) + "\n"
    }

    struct Unresolved: Codable, Comparable {
        let name: String
        let context: String
        private var key: String { name + context }
        static func < (lhs: Unresolved, rhs: Unresolved) -> Bool {
            lhs.key < rhs.key
        }
    }

    private(set) var unresolved = [String:Unresolved]()

    mutating func addUnresolved(name: String, context: String) {
        unresolved[name] = .init(name: name, context: context)
        inc(.autolinkUnresolved)
    }

    func buildUnresolvedJSON() throws -> String? {
        guard !unresolved.isEmpty else {
            return nil
        }
        return try JSON.encode(unresolved.values.sorted()) + "\n"
    }

    mutating func reset() {
        Counter.allCases.forEach { counters[$0.rawValue] = 0 }
        undocumented.removeAll()
        unresolved.removeAll()
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
