//
//  TestGen.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let gen: Gen

    init() {
        config = Config()
        gen = Gen(config: config)
    }

    func configure(cliOpts: [String]) throws {
        try config.processOptions(cliOpts: cliOpts)
    }
}

extension DocsData {
    init() {
        self.init(meta: Meta(version: "TEST"), toc: [], pages: [])
    }
}

class TestGen: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testCreateOutputDir() throws {
        let fm = FileManager.default
        let outputDir = fm.temporaryFileURL()
        XCTAssertFalse(fm.fileExists(atPath: outputDir.path))
        let system = System()
        try system.configure(cliOpts: ["--output", outputDir.path])
        try system.gen.generate(docsData: DocsData())
        XCTAssertTrue(fm.fileExists(atPath: outputDir.path))
        try fm.removeItem(at: outputDir)
    }

    func testDeleteExistingOutputDir() throws {
        let fm = FileManager.default
        let tmp = try TemporaryDirectory()
        let markerFileURL = tmp.directoryURL.appendingPathComponent("MARK")
        XCTAssertTrue(fm.createFile(atPath: markerFileURL.path, contents: nil))
        let system = System()
        try system.configure(cliOpts: ["--output", tmp.directoryURL.path, "--clean"])
        try system.gen.generate(docsData: DocsData())
        XCTAssertTrue(fm.fileExists(atPath: tmp.directoryURL.path))
        XCTAssertFalse(fm.fileExists(atPath: markerFileURL.path))
    }

    func testPageGen() throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        TestLogger.install()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--products", "docs-summary-json"])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count)

        let spmTestDocsSummaryJsonURL = fixturesURL.appendingPathComponent("SpmSwiftModule.docs-summary.json")

        let actualJson = TestLogger.shared.outputBuf[0] + "\n"

        // to fix up when it changes...
        // try actualJson.write(to: spmTestDocsSummaryJsonURL, atomically: true, encoding: .utf8)

        let expectedJson = try String(contentsOf: spmTestDocsSummaryJsonURL)
        XCTAssertEqual(expectedJson, actualJson)
    }
}
