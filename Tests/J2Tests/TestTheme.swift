//
//  TestTheme.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import Mustache
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let themes: GenThemes

    init() {
        config = Config()
        themes = GenThemes(config: config)
    }
}

class TestTheme: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testThemesDiscovery() throws {
        let system = System()
        XCTAssertEqual(["fw2020"], system.themes.builtInNames)
    }

    private func checkGoodThemeSelection(opts: [String]) throws {
        let system = System()
        try system.config.processOptions(cliOpts: opts)
        let url = system.themes.themeURLFromOpt
        XCTAssertEqual("fw2020", url.lastPathComponent)

        let theme = try system.themes.select()
        XCTAssertEqual(".html", theme.fileExtension)
    }

    func testImplicitThemeSelection() throws {
        try checkGoodThemeSelection(opts: [])
    }

    func testExplicitThemeSelection() throws {
        try checkGoodThemeSelection(opts: ["--theme", "fw2020"])
    }

    private func checkBadThemeSelection(path: String) {
        let system = System()
        AssertThrows(try system.config.processOptions(cliOpts: ["--theme", path]),
                     OptionsError.self)
    }

    // bad directory
    func testBadThemeSelection() {
        checkBadThemeSelection(path: "not-a-theme")
    }

    // directory exists, missing template
    func testBadThemeSelection2() throws {
        let tmp = try TemporaryDirectory()
        checkBadThemeSelection(path: tmp.directoryURL.path)
    }

    // Theme yaml and template refs
    func testThemeYaml() throws {
        let themeURL = fixturesURL.appendingPathComponent("Theme")
        let theme = try Theme(url: themeURL)
        XCTAssertEqual(".md", theme.fileExtension)
        XCTAssertEqual(["top.scss"], theme.scssFilenames)
        let data = ["name" : "Fred", "type" : "Barney"]
        let rendered = try theme.renderTemplate(data: data)
        XCTAssertEqual("Fred\nBarney\n\n", rendered.html)
    }

    func testThemeYamlSass() throws {
        let themeURL = fixturesURL.appendingPathComponent("Theme")
        let theme = try Theme(url: themeURL)
        let tmpDir = try TemporaryDirectory()
        try theme.copyAssets(to: tmpDir.directoryURL)
        let dstCssDirURL = tmpDir.directoryURL.appendingPathComponent("css")
        let cssFileURL = dstCssDirURL.appendingPathComponent("top.css")
        XCTAssertTrue(FileManager.default.fileExists(atPath: cssFileURL.path))
        let scssFiles = dstCssDirURL.filesMatching("*.scss")
        XCTAssertTrue(scssFiles.isEmpty)
        let css = try String(contentsOf: cssFileURL)
        XCTAssertEqual(".j2-article p {\n  color: blue; }\n", css)
    }

    private func createThemeDirs() throws -> TemporaryDirectory {
        let tmpDir = try TemporaryDirectory()
        let templatesDir = tmpDir.directoryURL.appendingPathComponent("templates")
        try FileManager.default.createDirectory(at: templatesDir, withIntermediateDirectories: false)
        return tmpDir
    }

    // test-bad-theme-yaml
    func testBadThemeYaml() throws {
        let tmpDir = try createThemeDirs()
        try "bad_attr: something".write(to: tmpDir.directoryURL.appendingPathComponent("theme.yaml"))
        AssertThrows(try Theme(url: tmpDir.directoryURL), OptionsError.self)
    }

    // test-mustache-failure
    func testBadMustacheTemplate() throws {
        let tmpDir = try createThemeDirs()
        do {
            let theme = try Theme(url: tmpDir.directoryURL)
            XCTFail("Managed to create theme with bad templates \(theme)")
        } catch {
            // this is some Cocoa error...
        }
    }
}
