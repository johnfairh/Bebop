//
//  TestStats.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import SourceKittenFramework
@testable import J2Lib

private struct System {
    let config: Config
    let stats: Stats
    let merge: Merge

    init() {
        config = Config()
        stats = Stats(config: config)
        merge = Merge(config: config)
    }

    func run(_ opts: [String] = []) throws {
        try config.processOptions(cliOpts: opts)
    }
}

class TestStats: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testStatsFile() throws {
        let tmpDir = try TemporaryDirectory()
        let statsFileURL = tmpDir.directoryURL.appendingPathComponent("stats.json")
        let system = System()
        try system.run(["--output-stats=\(statsFileURL.path)", "--debug"])
        Stats.inc(.gatherLocalizationKey)
        try system.stats.createStatsFile(outputURL: tmpDir.directoryURL)
        system.stats.debugReport()

        // verify
        let statsData = try JSONSerialization.jsonObject(with: Data(contentsOf: statsFileURL))
        guard let stats = statsData as? Dictionary<String, Any>,
            let count = stats[StatsDb.Counter.gatherLocalizationKey.rawValue] as? Int,
            count == 1 else {
                XCTFail("Couldn't round-trip stats")
                return
        }
    }

    func testUndocReport() throws {
        let tmpDir = try TemporaryDirectory()
        let system = System()
        try system.run()
        let structDef1 = SourceKittenDict
            .mkStruct(name: "MyStruct")
            .with(field: .docLine, value: Int64(100))
            .with(accessibility: .public)
        let structDef2 = SourceKittenDict
            .mkStruct(name: "MyStruct2")
            .with(field: .docLine, value: Int64(20))
            .with(accessibility: .public)
        let pass = SourceKittenDict
            .mkFile()
            .with(children: [structDef1, structDef2])
            .asGatherDef()
            .asPass(moduleName: "Mod", pathName: "/foo/bar.swift")

        let defs = try system.merge.merge(gathered: [pass])
        XCTAssertEqual(2, defs.count)

        try system.stats.createUndocumentedFile(outputURL: tmpDir.directoryURL)

        // verify
        let undocURL = tmpDir.directoryURL.appendingPathComponent("undocumented.json")
        let undocData = try JSONSerialization.jsonObject(with: Data(contentsOf: undocURL))
        guard let undocs = undocData as? [[String: Any]] else {
            XCTFail("Couldn't round-trip undoc")
            return
        }
        XCTAssertEqual(2, undocs.count)
        let symbols = undocs.compactMap { $0["symbol"] as? String }
        XCTAssertEqual(["MyStruct2", "MyStruct"], symbols)
    }

    func testNoUndocReport() throws {
        let tmpDir = try TemporaryDirectory()
        let system = System()
        try system.run()
        try system.stats.createUndocumentedFile(outputURL: tmpDir.directoryURL)
        let undocURL = tmpDir.directoryURL.appendingPathComponent("undocumented.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: undocURL.path))
    }
}
