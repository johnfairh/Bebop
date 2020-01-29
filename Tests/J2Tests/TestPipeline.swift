//
//  TestPipeline.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

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
        XCTAssertEqual([Version.j2libVersion], TestLogger.shared.messageBuf)
    }

    // Pipeline from CLI
    // (using --version here to avoid running the whole thing, have to think...)
    func testCliPipeline() throws {
        TestLogger.install()
        let rc = Pipeline.main(argv: ["--version"])
        XCTAssertEqual(0, rc)
        XCTAssertEqual([Version.j2libVersion], TestLogger.shared.messageBuf)

        // CLI prefixes
        logWarning("www")
        XCTAssertEqual("j2: warning: www", TestLogger.shared.diagsBuf.last)
        logError("eee")
        XCTAssertEqual("j2: error: eee", TestLogger.shared.diagsBuf.last)
        TestLogger.shared.logger.activeLevels = Logger.allLevels
        logDebug("ddd")
        XCTAssertEqual("j2: debug: ddd", TestLogger.shared.diagsBuf.last)

        // Exception handling
        let rc2 = Pipeline.main(argv: ["--unpossible"])
        XCTAssertEqual(1, rc2)
        guard let eMsg = TestLogger.shared.diagsBuf.last else {
            XCTFail()
            return
        }
        XCTAssertTrue(eMsg.re_isMatch("^j2: error: .*--unpossible"), eMsg)
    }

    // Simple end-to-end run
    func testEndToEnd() throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftModule")
        let tempDir = try TemporaryDirectory()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--output", tempDir.directoryURL.path,
                                "--products", "docs"])
        // XXX site byte-check
    }
}
