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

class TestProducts: XCTestCase {
    override func setUp() {
        initResources()
    }

    func compare(product: String, against: String, cleanUpJSON: Bool = false, line: UInt = #line) throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        TestLogger.install()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--products", product])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count, line: line)

        let fixtureJSONURL = fixturesURL.appendingPathComponent(against)

        var actualJson = TestLogger.shared.outputBuf[0] + "\n"

        // to fix up when it changes...
        // try actualJson.write(to: fixtureJSONURL)

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
                line.contains(#""key.doc.file""# ) {
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

    func testFilesJson() throws {
        try compare(product: "files-json", against: "SpmSwiftModule.files.json", cleanUpJSON: true)
    }

    func testDeclsJson() throws {
        try compare(product: "decls-json", against: "SpmSwiftModule.decls.json")
    }

    func testPageGen() throws {
        try compare(product: "docs-summary-json", against: "SpmSwiftModule.docs-summary.json")
    }

    func testSiteGen() throws {
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        defer { unsetenv("J2_STATIC_DATE") }
        try compare(product: "docs-json", against: "SpmSwiftModule.docs.json")
    }
}
