//
//  TestSass.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib
import Foundation

class TestSass: XCTestCase {

    override func setUp() {
        initResources()
    }

    func testBasic() throws {
        let tmpFileURL = FileManager.default.temporaryFileURL()
        let sass = "div { a { color: blue; } }"
        try sass.write(to: tmpFileURL)
        let css = try Sass.render(scssFileURL: tmpFileURL)
        let flattened = css.re_sub(#"\s+"#, with: " ")
        XCTAssertEqual("div a { color: blue; } ", flattened)
    }

    func testBadFile() throws {
        AssertThrows(try Sass.render(scssFileURL: URL(fileURLWithPath: "/Not/real")), .errSassCompile)
    }

    func testBadContent() throws {
        let tmpFileURL = FileManager.default.temporaryFileURL()
        let sass = "not sass"
        try sass.write(to: tmpFileURL)
        do {
            let css = try Sass.render(scssFileURL: tmpFileURL)
            XCTFail("Managed to render nonsense as sass: \(css)")
        } catch {
            let str = String(describing: error)
            XCTAssertTrue(str.contains("Invalid CSS"))
            if let e = error as? BBError {
                print(e.description)
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

        let css = try Sass.render(scssFileURL: sass1URL)
        XCTAssertEqual("div {\n  color: red; }\n", css)
    }

    func testRenderInPlace() throws {
        try ["sass.scss", "sass.css.scss"].forEach { sassFilename in
            let tmpDir = try TemporaryDirectory()
            let sass = "div { color: red; }"
            let sassURL = tmpDir.directoryURL.appendingPathComponent(sassFilename)
            try sass.write(to: sassURL)
            try Sass.renderInPlace(scssFileURL: sassURL)
            let cssURL = tmpDir.directoryURL.appendingPathComponent("sass.css")
            let css = try String(contentsOf: cssURL)
            XCTAssertEqual("div {\n  color: red; }\n", css, sassFilename)
        }
    }
}
