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

    // Localization - for the generated products, not the app
    func testLocalizationBase() {
        XCTAssertEqual(Localization.defaultDescriptor,
                       Localization.default.description)
        let loc1 = Localization(descriptor: "a:b:c:d")
        XCTAssertEqual("a", loc1.tag)
        XCTAssertEqual("b", loc1.flag)
        XCTAssertEqual("c:d", loc1.label)

        let loc2 = Localization(descriptor: "a:b")
        XCTAssertEqual("a", loc2.tag)
        XCTAssertEqual("b", loc2.flag)
        XCTAssertEqual("a", loc2.label)

        let loc3 = Localization(descriptor: "a")
        XCTAssertEqual("a", loc3.tag)
        XCTAssertEqual("🇺🇳", loc3.flag)
        XCTAssertEqual("a", loc3.label)
    }

    func testLocalizations() {
        let locs1 = Localizations(mainDescriptor: nil, otherDescriptors: [])
        XCTAssertEqual(Localization.default, locs1.main)
        XCTAssertTrue(locs1.others.isEmpty)
        XCTAssertEqual([Localization.default], locs1.all)
        XCTAssertEqual(["en"], locs1.allTags)

        let ldEn = "en:EN:English"
        let ldFr = "fr:FR:French"
        let ldDe = "de:DE:German"

        let locs2 = Localizations(mainDescriptor: ldFr, otherDescriptors: [ldFr, ldDe, ldEn, ldDe])

        XCTAssertEqual(ldFr, locs2.main.description)
        XCTAssertEqual([ldDe, ldEn], locs2.others.map { $0.description })
        XCTAssertEqual([ldFr, ldDe, ldEn], locs2.all.map { $0.description })
        XCTAssertEqual(["fr", "de", "en"], locs2.allTags)
    }
}
