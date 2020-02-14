//
//  TestGen.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let gen: SiteGen

    init() {
        config = Config()
        gen = SiteGen(config: config)
    }

    func configure(cliOpts: [String]) throws {
        try config.processOptions(cliOpts: cliOpts)
    }
}

extension GenData.Meta {
    init() {
        self.init(version: "TEST")
    }
}

extension GenData {
    convenience init() {
        self.init(meta: Meta(), toc: [], pages: [])
    }
}

class TestGen: XCTestCase {
    override func setUp() {
        initResources()
    }

    // Output directory

    func testCreateOutputDir() throws {
        let fm = FileManager.default
        let outputDir = fm.temporaryFileURL()
        XCTAssertFalse(fm.fileExists(atPath: outputDir.path))
        let system = System()
        try system.configure(cliOpts: ["--output", outputDir.path])
        try system.gen.generateSite(genData: GenData())
        XCTAssertTrue(fm.fileExists(atPath: outputDir.path))
        try fm.removeItem(at: outputDir)
    }

    func testDeleteExistingOutputDir() throws {
        let fm = FileManager.default
        let tmp = try TemporaryDirectory()
        let markerFileURL = tmp.directoryURL.appendingPathComponent("MARK")
        XCTAssertTrue(fm.createFile(atPath: markerFileURL.path, contents: nil))
        let system = System()
        try system.configure(cliOpts: ["--output", tmp.directoryURL.path, "--clean"])
        try system.gen.generateSite(genData: GenData())
        XCTAssertTrue(fm.fileExists(atPath: tmp.directoryURL.path))
        XCTAssertFalse(fm.fileExists(atPath: markerFileURL.path))
    }

    // Page-Gen iterator

    private func mkPage(_ name: String) -> GenData.Page {
        var title = Localized<String>()
        Localizations.shared.allTags.forEach {
            title[$0] = "\($0)-\(name)"
        }
        return GenData.Page(guideURL: URLPieces(pageName: name), title: title, isReadme: false, content: nil)
    }

    func testPageGenIterator() throws {
        let meta = GenData.Meta()

        Localizations.shared = Localizations()
        let genData = GenData(meta: meta, toc: [],
                              pages: [mkPage("page1"), mkPage("page2")])

        var it = genData.makeIterator(fileExt: ".html")
        let it_1 = it.next()
        XCTAssertEqual("en", it_1?.languageTag)
        XCTAssertEqual("en-page1", it_1?.data[.pageTitle] as? String)
        let it_2 = it.next()
        XCTAssertEqual("en-page2", it_2?.data[.pageTitle] as? String)
        XCTAssertNil(it.next())
        XCTAssertNil(it.next())
    }

    func testMultiLanguagePageGenIterator() throws {
        let meta = GenData.Meta()

        Localizations.shared =
            Localizations(mainDescriptor: Localization.defaultDescriptor,
                          otherDescriptors: ["fr:FR:frfrfr"])
        let genData = GenData(meta: meta, toc: [],
                              pages: [mkPage("page1"), mkPage("page2")])

        var it = genData.makeIterator(fileExt: ".html")
        let it_1 = it.next()
        XCTAssertEqual("en", it_1?.languageTag)
        XCTAssertEqual("en-page1", it_1?.data[.pageTitle] as? String)
        let it_2 = it.next()
        XCTAssertEqual("en-page2", it_2?.data[.pageTitle] as? String)
        let loc_2 = it_2!.getLocation()
        XCTAssertEqual("page2.html", loc_2.filePath)
        XCTAssertEqual("page2.html", loc_2.urlPath)
        XCTAssertEqual("", loc_2.reversePath)
        let loc_2_fr = it_2!.getLocation(languageTag: "fr")
        XCTAssertEqual("fr/page2.html", loc_2_fr.filePath)
        XCTAssertEqual("../", loc_2_fr.reversePath)
        let it_3 = it.next()
        XCTAssertEqual("fr", it_3?.languageTag)
        XCTAssertEqual("fr-page1", it_3?.data[.pageTitle] as? String)
        let it_4 = it.next()
        XCTAssertEqual("fr-page2", it_4?.data[.pageTitle] as? String)
        XCTAssertNil(it.next())
    }

    // Site-Gen global data
    func testGlobalData() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-attribution", "--no-hide-search"])
        let globalData = system.gen.globalData
        XCTAssertEqual(Version.j2libVersion, globalData[.j2libVersion] as? String)
        XCTAssertEqual(false, globalData[.hideSearch] as? Bool)
        XCTAssertEqual(true, globalData[.hideAttribution] as? Bool)
        XCTAssertEqual(66, globalData[.docCoverage] as? Int)
        XCTAssertNil(globalData[.customHead])
    }

    // Site-Gen global data
    func testHideCoverage() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-documentation-coverage"])
        let globalData = system.gen.globalData
        XCTAssertNil(globalData[.docCoverage])
    }

    private func checkTitles(_ cliOpts: [String], _ modules: [String],
                             _ title: String?, _ bcRoot: String, line: UInt = #line) throws {
        let system = System()
        try system.configure(cliOpts: cliOpts)
        system.config.published.moduleNames = modules
        let meta = GenData.Meta(version: "")
        let data = GenData(meta: meta, toc: [], pages: [])
        let atitle = system.gen.buildDocsTitle(genData: data)
        let abreadcrumbsRoot = system.gen.buildBreadcrumbRoot(genData: data)
        if let title = title {
            XCTAssertEqual(title, atitle["en"]!, line: line)
        }
        XCTAssertEqual(bcRoot, abreadcrumbsRoot["en"]!, line: line)
    }

    // Site-Gen title generation
    func testDocsTitles() throws {
        try checkTitles([], [], "Module docs", "Index")
        try checkTitles([], ["MM"], "MM docs", "MM")
        try checkTitles(["--module-version=1.2"], ["MM"], "MM 1.2 docs", "MM")
        try checkTitles(["--title=TT"], ["MM"], "TT", "MM")
        try checkTitles(["--breadcrumbs-root=BB"], ["MM"], "MM docs", "BB")
        try checkTitles([], ["MM", "M2"], nil, "Index")
    }

    // Copyright gen
    private func checkCopyright(cliArgs: [String], langMatches: [String:[String]], line: UInt = #line) throws {
        let config = Config()
        let copyright = GenCopyright(config: config)
        try config.processOptions(cliOpts: cliArgs)
        let generated = copyright.generate().html
        langMatches.forEach { kv in
            let html = generated[kv.key]!
            kv.value.forEach { match in
                XCTAssertTrue(html.html.contains(match), html.html, line: line)
            }
        }
    }

    func testCopyright() throws {
        /* Check auto path doesn't crash */
        try checkCopyright(cliArgs: [], langMatches: ["en": ["©"]])
        setenv("J2_STATIC_DATE", strdup("1") /* leak it */, 1)
        defer { unsetenv("J2_STATIC_DATE") }
        try checkCopyright(cliArgs: [], langMatches: ["en": ["9999", "today"]])
        try checkCopyright(cliArgs: ["--author=Fred"], langMatches: ["en": ["9999 Fred"]])
        try checkCopyright(cliArgs: ["--author=Fred", "--author-url=http://foo.bar/"],
                           langMatches: ["en": [#"<a href="http://foo.bar/""#, ">Fred</a>"]])
        try checkCopyright(cliArgs: ["--copyright=_COPYRIGHT_"],
                           langMatches: ["en": ["<p><em>COPYRIGHT</em></p>"]])
    }
}
