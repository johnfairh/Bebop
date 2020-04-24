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
        let system = try System(cliArgs: ["--disable-apple-autolink"])
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
        guard let link = system.link(text: "String") else {
            XCTFail("Lookup 'String' failed")
            return
        }
        XCTAssertEqual(FormatAutolinkApple.APPLE_DOCS_BASE_URL +
                       "swift/string?language=swift",
                       link.primaryURL)
    }

    func testCache() throws {
        let system = try System()

        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitHit])
        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitMiss])

        let _ = system.link(text: "String")
        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitHit])
        let _ = system.link(text: "String")
        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitHit])

        // CAN'T DO UNTIL WE TEACH IT TO SOMETIMES FAIL!

//        let badName = "NEVEREVERASYMBOLNAME"
//
//        if let badLink = system.link(text: badName) {
//            XCTFail("Resolved badness: \(badLink)")
//            return
//        }
//        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitHit])
//        XCTAssertEqual(0, Stats.db[.autolinkAppleCacheHitMiss])
//
//        let _ = system.link(text: badName)
//        XCTAssertEqual(1, Stats.db[.autolinkAppleCacheHitMiss])
    }

    #endif

}
