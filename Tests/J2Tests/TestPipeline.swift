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
    // Check resource bundle xctest setup
    func testResourceSetup() {
        initResourceBundle()
        Resources.initialize()
    }

    // Test a chunk of localization selection
    func testLanguageChoice() {
        func setLang(_ l: String) { setenv("LANG", strdup(l) /* leak it */, 1) }
        let origLang = ProcessInfo.processInfo.environment["LANG"]
        defer { setLang(origLang ?? "") }

        setLang("fr_FR.UTF-8")
        XCTAssertEqual("fr", Resources.chooseLanguageFromEnvironment(choices: ["fr", "en"]).0)
        XCTAssertNil(Resources.chooseLanguageFromEnvironment(choices: ["en"]).0)

        setLang("fr_FR")
        XCTAssertEqual("fr_FR", Resources.chooseLanguageFromEnvironment(choices: ["fr", "fr_FR"]).0)
        XCTAssertNil(Resources.chooseLanguageFromEnvironment(choices: ["fr_CA", "en"]).0)

        setLang("Nonsense")
        XCTAssertNil(Resources.chooseLanguageFromEnvironment(choices: ["en"]).0)

        setLang("")
        XCTAssertNil(Resources.chooseLanguageFromEnvironment(choices: ["en"]).0)

        unsetenv("LANG")
        XCTAssertNil(Resources.chooseLanguageFromEnvironment(choices: ["en"]).0)
    }

    // Pipeline construction but get out early
    func testPipelineSetup() {
        Do {
            initResourceBundle()
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let p = Pipeline(logger: TestLogger.shared.logger)
            try p.run(argv: ["--version"])
            XCTAssertEqual([Version.j2libVersion], TestLogger.shared.messageBuf)
        }
    }

    // Pipeline from CLI
    // (using --version here to avoid running the whole thing, have to think...)
    func testCliPipeline() {
        Do {
            initResourceBundle()
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
            XCTAssertTrue(eMsg.re_isMatch("^j2: error: .*--unpossible"))
        }
    }
}
