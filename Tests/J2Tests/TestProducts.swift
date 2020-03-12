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

    func compareSwift(product: String, cliArgs: [String] = [], against: String, line: UInt = #line) throws {
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try compare(["--source-directory", spmTestURL.path] + cliArgs, product, against: against, line: line)
    }

    func compareObjC(product: String, against: String, line: UInt = #line) throws {
        let headerURL = fixturesURL
            .appendingPathComponent("ObjectiveC")
            .appendingPathComponent("Header.h")
        try compare(["--objc-header-file", headerURL.path], product, against: against, line: line)
    }

    func compare(_ args: [String], _ product: String, against: String, line: UInt = #line) throws {
        let pipeline = Pipeline()
        TestLogger.install()
        try pipeline.run(argv: args + ["--products", product])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count, line: line)

        let fixtureJSONURL = fixturesURL.appendingPathComponent(against)

        var actualJson = TestLogger.shared.outputBuf[0] + "\n"

        if doFixup {
            try actualJson.write(to: fixtureJSONURL)
        }

        var expectedJson = try String(contentsOf: fixtureJSONURL)
        if product == "files-json" || product == "decls-json" {
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
        try compareSwift(product: "files-json", against: "SpmSwiftModule.files.json")
    }

    func testDeclsJsonSwift() throws {
        try compareSwift(product: "decls-json",
                         cliArgs: ["--min-acl=private"],
                         against: "SpmSwiftModule.decls.json")
    }

    #if os(macOS)
    func testFilesJsonObjC() throws {
        try compareObjC(product: "files-json", against: "ObjectiveC.files.json")
    }

    func testDeclsJsonObjC() throws {
        try compareObjC(product: "decls-json", against: "ObjectiveC.decls.json")
    }

    func testMixedSwiftObjC() throws {
        let configURL = fixturesURL
            .appendingPathComponent("SpmSwiftPackage")
            .appendingPathComponent("mixed-objc-swift-j2.yaml")
        try compareSwift(product: "docs-summary-json",
                         cliArgs: ["--config=\(configURL.path)", "--min-acl=private"],
                         against: "MixedSwiftObjC.docs-summary.json")
    }
    #endif

    func testAclFiltering() throws {
        let rootDir = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try rootDir.withCurrentDirectory { // test relative file glob
            try compareSwift(product: "decls-json",
                             cliArgs: [
                                "--modules=SpmSwiftModule5",
                                "--undocumented-text=Undoc",
                                "--include-source-files=/*/A*.swift",
                                "--exclude-source-files", "*/Aexclude.swift",
                                "--exclude-names", "^_"
                             ],
                             against: "SpmSwiftModule5.decls.json")
        }
    }

    func testPageGenSwift() throws {
        try compareSwift(product: "docs-summary-json",
                         cliArgs: ["--modules=SpmSwiftModule,SpmSwiftModule2,SpmSwiftModule3",
                                   "--min-acl=private"],
                         against: "SpmSwiftModule.docs-summary.json")
    }

    func testSiteGenSwift() throws {
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        defer { unsetenv("J2_STATIC_DATE") }
        try compareSwift(product: "docs-json",
                         cliArgs: ["--min-acl=private"],
                         against: "SpmSwiftModule.docs.json")
    }
}
