//
//  TestProducts.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

// Binary-check fixtures for the json products fils

//private var doFixup = true
private var doFixup = false

class TestProducts: XCTestCase {
    override func setUp() {
        initResources()
    }

    func compareSwift(product: String, cliArgs: [String] = [], against: String, cleanUpJSON: Bool = false, line: UInt = #line) throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        TestLogger.install()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--products", product] + cliArgs)
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count, line: line)
        try compare(against: against, cleanUpJSON: cleanUpJSON, line: line)
    }

    func compareObjC(product: String, against: String, cleanUpJSON: Bool = false, line: UInt = #line) throws {
        let pipeline = Pipeline()
        let headerURL = fixturesURL
            .appendingPathComponent("ObjectiveC")
            .appendingPathComponent("Header.h")
        TestLogger.install()
        try pipeline.run(argv: ["--objc-header-file", headerURL.path,
                                "--products", product])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count, line: line)
        try compare(against: against, cleanUpJSON: cleanUpJSON, line: line)
    }

    func compare(against: String, cleanUpJSON: Bool = false, line: UInt = #line) throws {
        let fixtureJSONURL = fixturesURL.appendingPathComponent(against)

        var actualJson = TestLogger.shared.outputBuf[0] + "\n"

        if doFixup {
            try actualJson.write(to: fixtureJSONURL)
        }

        var expectedJson = try String(contentsOf: fixtureJSONURL)
        if cleanUpJSON {
            actualJson = cleanUpJson(file: actualJson)
            expectedJson = cleanUpJson(file: expectedJson)
        }
        XCTAssertEqual(expectedJson, actualJson, line: line)
    }

    /// Helper to clean up the files json to eliminate host/platform differencs.
    private func cleanUpJson(file: String) -> String {
        let lines = file.split(separator: "\n")
        let cleanedLines = lines.compactMap { line -> Substring? in
            if line.contains(#""key.usr""#) ||
                line.contains(#""key.typeusr""#) ||
                line.contains(#""key.doc.full_as_xml""#) {
                // linux
                return nil
            }
            if line.contains(#""key.filepath""#) ||
                line.contains(#""key.doc.file""#) ||
                line.contains(#""file_pathname""#) {
                // filesystem
                return nil
            }
            if line.hasPrefix(#"    ""#) {
                // pathname key
                return nil
            }
            return line
        }
        return cleanedLines.joined(separator: "\n")
    }

    func testFilesJsonSwift() throws {
        try compareSwift(product: "files-json", against: "SpmSwiftModule.files.json", cleanUpJSON: true)
    }

    func testDeclsJsonSwift() throws {
        try compareSwift(product: "decls-json", against: "SpmSwiftModule.decls.json", cleanUpJSON: true)
    }

    #if os(macOS)
    func testFilesJsonObjC() throws {
        try compareObjC(product: "files-json", against: "ObjectiveC.files.json", cleanUpJSON: true)
    }

    func testDeclsJsonObjC() throws {
        try compareObjC(product: "decls-json", against: "ObjectiveC.decls.json", cleanUpJSON: true)
    }
    #endif

    func testPageGenSwift() throws {
        try compareSwift(product: "docs-summary-json",
                         cliArgs: ["--modules=SpmSwiftModule,SpmSwiftModule3"],
                         against: "SpmSwiftModule.docs-summary.json")
    }

    func testSiteGenSwift() throws {
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        defer { unsetenv("J2_STATIC_DATE") }
        try compareSwift(product: "docs-json", against: "SpmSwiftModule.docs.json")
    }
}
