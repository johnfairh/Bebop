//
//  TestProducts.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

// Binary-check fixtures for the json & html products files

private var doFixup = true
//private var doFixup = false

// apple autolink disabled for tests that run on linux...

class TestProducts: XCTestCase {
    override func setUp() {
        initResources()
    }

    func compareSwift(product: String, cliArgs: [String] = [], against: String, line: UInt = #line) throws {
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try compare(["--source-directory", spmTestURL.path] + cliArgs, product, against: against, line: line)
    }

    func compareObjC(product: String, cliArgs: [String] = [], against: String, line: UInt = #line) throws {
        let headerURL = fixturesURL
            .appendingPathComponent("ObjectiveC")
            .appendingPathComponent("Header.h")
        try compare(["--objc-header-file", headerURL.path] + cliArgs, product, against: against, line: line)
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
        try compareSwift(product: "files-json",
                         cliArgs: ["--no-apple-autolink"],
                         against: "SpmSwiftModule.files.json")
    }

    func testDeclsJsonSwift() throws {
        try compareSwift(product: "decls-json",
                         cliArgs: ["--min-acl=private", "--no-apple-autolink"],
                         against: "SpmSwiftModule.decls.json")
    }

    #if os(macOS)
    func testFilesJsonObjC() throws {
        try compareObjC(product: "files-json", against: "ObjectiveC.files.json")
    }

    func testDeclsJsonObjC() throws {
        try compareObjC(product: "decls-json", against: "ObjectiveC.decls.json")
    }

    func testDeclsJsonObjCNoObjC() throws {
        try compareObjC(product: "decls-json",
                        cliArgs: ["--hide-language=objc"],
                        against: "ObjectiveC.noobjc.decls.json")
    }

    func testMixedSwiftObjC() throws {
        let configURL = fixturesURL
            .appendingPathComponent("SpmSwiftPackage")
            .appendingPathComponent("mixed-objc-swift-j2.yaml")
        try compareSwift(product: "docs-json",
                         cliArgs: ["--config=\(configURL.path)"],
                         against: "MixedSwiftObjC.docs.json")
    }

    func testMixedSwiftObjCNoSwift() throws {
        let configURL = fixturesURL
            .appendingPathComponent("SpmSwiftPackage")
            .appendingPathComponent("mixed-objc-swift-j2.yaml")
        try compareSwift(product: "decls-json",
                         cliArgs: ["--config=\(configURL.path)",
                                   "--hide-language=swift"],
                         against: "MixedSwiftObjC.noswift.decls.json")
    }

    func testFilesJsonSymbolGraph() throws {
        guard TestSymbolGraph.isMyLaptop else { return }
        TestSymbolGraph.useCustom(); defer { TestSymbolGraph.reset() }

        let binDirURL = fixturesURL.appendingPathComponent("Swift53")

        try compare([
            "--symbolgraph-search-paths", binDirURL.path,
            "--modules=SpmSwiftModule",
            "--build-tool=swift-symbolgraph"
            ],
            "files-json",
            against: "SpmSwiftModuleSymbolGraph.files.json")
    }

    func testPodspec() throws {
        try compare([
            "--podspec", fixturesURL.appendingPathComponent("Pod/Pod.podspec").path,
            "--min-acl=private"
            ],
            "files-json",
            against: "Pod.files.json")
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
                                "--exclude-names", "^_",
                                "--no-apple-autolink"
                             ],
                             against: "SpmSwiftModule5.decls.json")
        }
    }

    func testPageGenSwift() throws {
        try compareSwift(product: "docs-summary-json",
                         cliArgs: ["--modules=SpmSwiftModule,SpmSwiftModule2,SpmSwiftModule3",
                                   "--min-acl=private",
                                   "--merge-modules",
                                   "--no-apple-autolink"],
                         against: "SpmSwiftModule.docs-summary.json")
    }

    func testSiteGenSwift() throws {
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        setenv("J2_STATIC_VERSION", strdup("1"), 1)
        defer {
            unsetenv("J2_STATIC_DATE")
            unsetenv("J2_STATIC_VERSION")
        }
        try compareSwift(product: "docs-json",
                         cliArgs: ["--min-acl=private", "--no-apple-autolink"],
                         against: "SpmSwiftModule.docs.json")
    }

    // Full html tests
    func testHtmlLayout() throws {
        let layoutRoot = fixturesURL.appendingPathComponent("LayoutTest")
        let options = [
            "--config=\(layoutRoot.path)/.j2.yaml",
            "--source-directory=\(layoutRoot.path)",
            "--no-apple-autolink"
        ]

        try doTestSiteFiles(args: options, goodDocsURL: layoutRoot.appendingPathComponent("docs"))
    }

    func testJazzyHtmlLayout() throws {
        let themeDirURL = fixturesURL.appendingPathComponent("JazzyAppleTheme")
        let packageDirURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let docsDirURL = packageDirURL.appendingPathComponent("jazzy_docs")
        let guideURL = fixturesURL.appendingPathComponent("LayoutTest/guides/*.md")
        let options = [
            "--source-directory=\(packageDirURL.path)",
            "--theme=\(themeDirURL.path)",
            "--module=SpmSwiftModule",
            "--min-acl=private",
            "--guides=\(guideURL.path)",
            "--clean",
            "--deployment-url=http://www.google.com/",
            "--code-host-url=http://www.bbc.co.uk/",
            "--code-host-file-url=http://www.bbc.co.uk/",
            "--no-apple-autolink"]

        try doTestSiteFiles(args: options, goodDocsURL: docsDirURL)
    }

    // Full markdown tests
    func testMarkdownNested() throws {
        let packageDirURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let docsDirURL = packageDirURL.appendingPathComponent("md_docs")

        let options = [
            "--source-directory=\(packageDirURL.path)",
            "--config=\(packageDirURL.appendingPathComponent("markdown-j2.yaml").path)"]

        try doTestSiteFiles(args: options, goodDocsURL: docsDirURL)
    }

    private func doTestSiteFiles(args: [String], goodDocsURL: URL) throws {
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        setenv("J2_STATIC_VERSION", strdup("1"), 1)
        defer {
            unsetenv("J2_STATIC_DATE")
            unsetenv("J2_STATIC_VERSION")
        }

        let tmpDir = try TemporaryDirectory()
        let newDocsURL  = tmpDir.directoryURL

        var options = args
        if doFixup {
            options.append("--output=\(goodDocsURL.path)")
        } else {
            options.append("--output=\(newDocsURL.path)")
        }

        let pipeline = Pipeline()
        TestLogger.install()
        try pipeline.run(argv: options)

        if doFixup {
            return
        }

        let goodFiles = enumeratedFiles(under: goodDocsURL).sorted()
        let newFiles = enumeratedFiles(under: newDocsURL).sorted()
        if goodFiles != newFiles {
            let diff = newFiles.difference(from: goodFiles)
            XCTFail("File manifest difference: \(diff)")
        }

        try newFiles.forEach { path in
            let goodFileURL = goodDocsURL.appendingPathComponent(path)
            let newFileURL = newDocsURL.appendingPathComponent(path)
            let goodVersion = try String(contentsOf: goodFileURL)
            let newVersion = try String(contentsOf: newFileURL)
            if goodVersion != newVersion {
                XCTFail("Mismatch on \(path).")
                print("diff \(goodFileURL.path) \(newFileURL.path)")
            }
        }
    }

    func enumeratedFiles(under url: URL) -> [String] {
        let enumerator = FileManager.default.enumerator(atPath: url.path)!
        return enumerator.compactMap {
            guard let path = $0 as? String,
                path.re_isMatch(#"(html|json|svg|plist|xml|md)$"#),
                !path.re_isMatch("undocumented.json$") else {
                    return nil
            }
            return path
        }
    }
}
