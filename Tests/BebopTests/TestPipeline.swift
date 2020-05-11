//
//  TestPipeline.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

class TestPipeline: XCTestCase {
    override func setUp() {
        prepareResourceBundle()
    }

    // Pipeline construction but get out early
    func testPipelineSetup() throws {
        TestLogger.install()
        TestLogger.shared.expectNoDiags = true
        let p = Pipeline(logger: TestLogger.shared.logger)
        try p.run(argv: ["--version"])
        XCTAssertEqual([Version.bebopLibVersion], TestLogger.shared.messageBuf)
    }

    // Pipeline from CLI
    // (using --version here to avoid running the whole thing, have to think...)
    func testCliPipeline() throws {
        TestLogger.install()
        let rc = Pipeline.main(argv: ["--version"])
        XCTAssertEqual(0, rc)
        XCTAssertEqual([Version.bebopLibVersion], TestLogger.shared.messageBuf)

        // CLI prefixes
        logWarning("www")
        XCTAssertEqual("bebop: warning: www", TestLogger.shared.diagsBuf.last)
        logError("eee")
        XCTAssertEqual("bebop: error: eee", TestLogger.shared.diagsBuf.last)
        TestLogger.shared.logger.activeLevels = Logger.allLevels
        logDebug("ddd")
        XCTAssertEqual("bebop: debug: ddd", TestLogger.shared.diagsBuf.last)

        // Exception handling
        let rc2 = Pipeline.main(argv: ["--unpossible"])
        XCTAssertEqual(1, rc2)
        guard let eMsg = TestLogger.shared.diagsBuf.last else {
            XCTFail()
            return
        }
        XCTAssertTrue(eMsg.re_isMatch("^bebop: error: .*--unpossible"), eMsg)
    }

    // Simple end-to-end run
    func testEndToEnd() throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let tempDir = try TemporaryDirectory()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--output", tempDir.directoryURL.path,
                                "--products", "docs"])
    }

    func testBadProducts() throws {
        let pipeline = Pipeline()

        AssertThrows(try pipeline.run(argv: ["--products=theme,stats-json"]), .errCfgThemeCopy)
    }
}
