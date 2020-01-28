//
//  TestResources.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

class TestResources: XCTestCase {
    // Check resource bundle xctest setup
    func testResourceSetup() {
        prepareResourceBundle()
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
}
