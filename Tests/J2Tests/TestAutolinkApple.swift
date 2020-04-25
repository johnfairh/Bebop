//
//  TestAutolinkApple.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let format: Format

    init(cliArgs: [String] = []) throws {
        config = Config()
        format = Format(config: config)
        try config.processOptions(cliOpts: cliArgs)
    }

    func link(text: String) -> Autolink? {
        format.autolink.autolinkApple.autolink(text: text)
    }
}


class TestAutolinkApple: XCTestCase {
    override func setUp() {
        initResources()
    }

    // MARK: Xcode option

    #if os(macOS)

    func testXcodeOptions() throws {
        let tmpDir = try TemporaryDirectory()
        let miscDir = try tmpDir.createDirectory()
        let appDir = try tmpDir.createDirectory(name: "Xcode.app")

        AssertThrows(try System(cliArgs: ["--apple-autolink-xcode-path", miscDir.directoryURL.path]), OptionsError.self)

        let system = try System(cliArgs: ["--apple-autolink-xcode-path", appDir.directoryURL.path])
        XCTAssertEqual(appDir.directoryURL
            .appendingPathComponent("Contents")
            .appendingPathComponent(FormatAutolinkApple.CONTENTS_MAP_DB_PATH).path,
                       system.format.autolink.autolinkApple.databaseURL?.path)

        let system2 = try System()
        guard let dbURL = system2.format.autolink.autolinkApple.databaseURL else {
            XCTFail("Couldn't find default DB URL")
            return
        }
        try dbURL.checkIsFile()
    }

    func testGlobalDisable() throws {
        let system = try System(cliArgs: ["--no-apple-autolink"])
        if let link = system.link(text: "String") {
            XCTFail("Got unexpected answer from disabled autolinker: \(link)")
            return
        }
    }

    func testLanguageMap() {
        [Int64(0), Int64(1)].forEach { appleId in
            guard let language = DefLanguage(appleId: appleId) else {
                XCTFail("Couldn't create language from \(appleId)")
                return
            }
            XCTAssertEqual(appleId, language.appleId)
        }

        XCTAssertEqual(DefLanguage.swift, DefLanguage(appleId: 0))
        XCTAssertEqual(DefLanguage.objc, DefLanguage(appleId: 1))
        XCTAssertNil(DefLanguage(appleId: 2))
        XCTAssertNil(DefLanguage(appleId: 12))
    }

    func testBadDb() throws {
        let tmpDir = try TemporaryDirectory()
        let appDir = try tmpDir.createDirectory(name: "Xcode.app")

        let system = try System(cliArgs: ["--apple-autolink-xcode-path", appDir.directoryURL.path])
        TestLogger.install()
        if let link = system.link(text: "String") {
            XCTFail("Got answer from imaginary database: \(link)")
            return
        }
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    func testBasicLookup() throws {
        let system = try System()

        ["String", "Swift.String"].forEach { text in
            guard let link = system.link(text: text) else {
                XCTFail("Lookup '\(text)' failed")
                return
            }
            XCTAssertEqual(FormatAutolinkApple.APPLE_DOCS_BASE_URL +
                           "swift/string?language=swift",
                           link.primaryURL)
        }
    }

    func testFunctionLookup() throws {
        let system = try System()
        guard let link = system.link(text: "String.init(repeating:count:)") else {
            XCTFail("String.init(repeating:count:)")
            return
        }
        XCTAssertTrue(link.primaryURL.re_isMatch(#"swift/string/\d+-init\?language=swift"#))
    }

    func testObjCFunctionLookup() throws {
        let system = try System()
        guard let link = system.link(text: "-[NSWindowDelegate windowWillResize:toSize:]") else {
            XCTFail("-[NSWindowDelegate windowWillResize:toSize:]")
            return
        }
        XCTAssertEqual(FormatAutolinkApple.APPLE_DOCS_BASE_URL +
                       "appkit/nswindowdelegate/1419292-windowwillresize?language=objc",
                       link.primaryURL)
    }

    func testDualLanguageLookup() throws {
        let system = try System()
        guard let link = system.link(text: "NSPersonNameComponentsFormatter") else {
            XCTFail("NSPersonNameComponentsFormatter")
            return
        }
        XCTAssertTrue(link.primaryURL.contains("language=objc"))
        XCTAssertTrue(link.html.re_isMatch(
            #"\bnspersonnamecomponentsformatter\b.*j2-objc.*\bpersonnamecomponentsformatter\b.*j2-swift j2-secondary"#))
    }

    func testLookupFailures() throws {
        let system = try System()
        if let link = system.link(text: "after") {
            XCTFail("Accidental link: \(link.primaryURL)")
            return
        }
    }

    func testCache() throws {
        let system = try System()

        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitHit])
        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitMiss])

        let _ = system.link(text: "String")
        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitHit])
        let _ = system.link(text: "String")
        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitHit])

        let badName = "NEVEREVERASYMBOLNAME"

        if let badLink = system.link(text: badName) {
            XCTFail("Resolved badness: \(badLink)")
            return
        }
        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitHit])
        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitMiss])

        let _ = system.link(text: badName)
        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitMiss])
    }

    #endif

}
