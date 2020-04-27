//
//  TestSass.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import Foundation

class TestSass: XCTestCase {

    func testBasic() throws {
        let tmpFileURL = FileManager.default.temporaryFileURL()
        let sass = "div { a { color: blue; } }"
        try sass.write(to: tmpFileURL)
        let css = try Sass.render(scssFile: tmpFileURL)
        let flattened = css.re_sub(#"\s+"#, with: " ")
        XCTAssertEqual("div a { color: blue; } ", flattened)
    }

    func testBadFile() throws {
        AssertThrows(try Sass.render(scssFile: URL(fileURLWithPath: "/Not/real")), Sass.Error.self)
    }

    func testBadContent() throws {
        let tmpFileURL = FileManager.default.temporaryFileURL()
        let sass = "not sass"
        try sass.write(to: tmpFileURL)
        do {
            let css = try Sass.render(scssFile: tmpFileURL)
            XCTFail("Managed to render nonsense as sass: \(css)")
        } catch {
            let str = String(describing: error)
            XCTAssertTrue(str.contains("Invalid CSS"))
            if let e = error as? Sass.Error {
                print(e.description + e.debugDescription)
            }
        }
    }

    func testImport() throws {
        let tmpDir = try TemporaryDirectory()
        let sass1 = #"@import "sass2""#
        let sass2 = "div { color: red; }"
        let sass1URL = tmpDir.directoryURL.appendingPathComponent("sass1.scss")
        let sass2URL = tmpDir.directoryURL.appendingPathComponent("sass2.scss")
        try sass1.write(to: sass1URL)
        try sass2.write(to: sass2URL)

        let css = try Sass.render(scssFile: sass1URL)
        XCTAssertEqual("div {\n  color: red; }\n", css)
    }
}
