//
//  TestAutolinkApple.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

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
    override func setUpWithError() throws {
        initResources()
    }

    func testGlobalDisable() throws {
        let system = try System(cliArgs: ["--no-apple-autolink"])
        if let link = system.link(text: "String") {
            XCTFail("Got unexpected answer from disabled autolinker: \(link)")
            return
        }
    }

    func testBasicLookup() throws {
        let system = try System()

        ["String", "Swift.String"].forEach { text in
            guard let link = system.link(text: text) else {
                XCTFail("Lookup '\(text)' failed")
                return
            }
            XCTAssertEqual(FormatAutolinkApple2.APPLE_DOCS_BASE_URL +
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

    func testDualLanguageHtml() throws {
        let system = try System()
        guard let link = system.link(text: "String") else {
            XCTFail("String")
            return
        }
        XCTAssertTrue(link.primaryURL.contains("language=swift"))
        XCTAssertTrue(link.html.re_isMatch(
            #"\bstring\b.*j2-swift.*\bstring\b.*j2-objc j2-secondary"#))
    }

    func testLookupFailures() throws {
        let system = try System()
        ["after", "Html"].forEach { badWord in
            if let link = system.link(text: badWord) {
                XCTFail("Accidental link from \(badWord): \(link.primaryURL)")
                return
            }
        }
    }
}
