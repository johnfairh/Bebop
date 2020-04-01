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
    let genPages: GenPages
    let gen: GenSite

    init() {
        config = Config()
        genPages = GenPages(config: config)
        gen = GenSite(config: config)
    }

    func configure(cliOpts: [String]) throws {
        try config.processOptions(cliOpts: cliOpts)
    }
}

extension GenData.Meta {
    init() {
        self.init(version: "TEST", languages: [], defaultLanguage: .swift)
    }
}

extension GenData {
    convenience init() {
        self.init(meta: Meta(), tocs: [], pages: [])
    }
}

class TestGen: XCTestCase {
    override func setUp() {
        initResources()
    }

    // MARK: Output directory

    func testCreateOutputDir() throws {
        let fm = FileManager.default
        let outputDir = fm.temporaryFileURL()
        XCTAssertFalse(fm.fileExists(atPath: outputDir.path))
        let system = System()
        try system.configure(cliOpts: ["--output", outputDir.path])
        try system.gen.generateSite(genData: GenData(), items: [])
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
        try system.gen.generateSite(genData: GenData(), items: [])
        XCTAssertTrue(fm.fileExists(atPath: tmp.directoryURL.path))
        XCTAssertFalse(fm.fileExists(atPath: markerFileURL.path))
    }

    // MARK: Page-Gen iterator

    private func mkPage(_ name: String) -> GenData.Page {
        var title = Localized<String>()
        Localizations.shared.allTags.forEach {
            title[$0] = "\($0)-\(name)"
        }
        return GenData.Page(guideURL: URLPieces(pathComponents: [name]), title: title, breadcrumbs: [], isReadme: false, content: nil)
    }

    func testPageGenIterator() throws {
        let meta = GenData.Meta()

        Localizations.shared = Localizations()
        let genData = GenData(meta: meta, tocs: [],
                              pages: [mkPage("page1"), mkPage("page2")])

        var it = genData.makeIterator(fileExt: ".html")
        let it_1 = it.next()
        XCTAssertEqual("en", it_1?.languageTag)
        XCTAssertEqual("en-page1", it_1?.data[.primaryPageTitle] as? String)
        let it_2 = it.next()
        XCTAssertEqual("en-page2", it_2?.data[.primaryPageTitle] as? String)
        XCTAssertNil(it.next())
        XCTAssertNil(it.next())
    }

    func testMultiLanguagePageGenIterator() throws {
        let meta = GenData.Meta()

        Localizations.shared =
            Localizations(mainDescriptor: Localization.defaultDescriptor,
                          otherDescriptors: ["fr:FR:frfrfr"])
        let genData = GenData(meta: meta, tocs: [],
                              pages: [mkPage("page1"), mkPage("page2")])

        var it = genData.makeIterator(fileExt: ".html")
        let it_1 = it.next()
        XCTAssertEqual("en", it_1?.languageTag)
        XCTAssertEqual("en-page1", it_1?.data[.primaryPageTitle] as? String)
        let it_2 = it.next()
        XCTAssertEqual("en-page2", it_2?.data[.primaryPageTitle] as? String)
        let loc_2 = it_2!.getLocation()
        XCTAssertEqual("page2.html", loc_2.filePath)
        XCTAssertEqual("", loc_2.reversePath)
        let it_3 = it.next()
        XCTAssertEqual("fr", it_3?.languageTag)
        XCTAssertEqual("fr-page1", it_3?.data[.primaryPageTitle] as? String)
        let it_4 = it.next()
        let loc_4 = it_4!.getLocation()
        XCTAssertEqual("fr/page2.html", loc_4.filePath)
        XCTAssertEqual("../", loc_4.reversePath)
        XCTAssertEqual("fr-page2", it_4?.data[.primaryPageTitle] as? String)
        XCTAssertNil(it.next())
    }

    // MARK: Global data

    // Site-Gen global data
    func testGlobalData() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-attribution", "--no-hide-search"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        XCTAssertEqual(Version.j2libVersion, globalData[.j2libVersion] as? String)
        XCTAssertEqual(false, globalData[.hideSearch] as? Bool)
        XCTAssertEqual(true, globalData[.hideAttribution] as? Bool)
        XCTAssertEqual(0, globalData[.docCoverage] as? Int)
        XCTAssertNil(globalData[.customHead])
    }

    // Site-Gen global data
    func testHideCoverage() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-documentation-coverage"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        XCTAssertNil(globalData[.docCoverage])
    }

    private func checkTitles(_ cliOpts: [String], _ modules: [String],
                             _ title: String?, _ bcRoot: String, line: UInt = #line) throws {
        let system = System()
        try system.configure(cliOpts: cliOpts)
        modules.forEach { m in
            system.config.published.moduleGroupPolicy[m] = .separate
        }
        let atitle = system.gen.buildDocsTitle()
        let abreadcrumbsRoot = system.gen.buildBreadcrumbsRoot()
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

    // MARK: Copyright

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

    // MARK: Language

    // Default language
    func testAutoDefaultLanguage() throws {
        let system = System()
        try system.configure(cliOpts: [])
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: []))
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: [.swift]))
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: [.swift, .objc]))
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: [.objc, .swift]))
        system.config.published.defaultLanguage = .objc
        XCTAssertEqual(.objc, system.genPages.pickDefaultLanguage(from: [.objc, .swift]))
    }

    func testUserDefaultLanguage() throws {
        let system = System()
        try system.configure(cliOpts: ["--default-language=objc"])
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: []))
        XCTAssertEqual(.swift, system.genPages.pickDefaultLanguage(from: [.swift]))
        XCTAssertEqual(.objc, system.genPages.pickDefaultLanguage(from: [.swift, .objc]))
        XCTAssertEqual(.objc, system.genPages.pickDefaultLanguage(from: [.objc, .swift]))
    }

    // MARK: Media

    func testMedia() throws {
        let tmpDir = try TemporaryDirectory()
        try "media1".write(to: tmpDir.directoryURL.appendingPathComponent("one.jpg"))
        try "media2".write(to: tmpDir.directoryURL.appendingPathComponent("two.png"))
        let system = System()
        TestLogger.install()
        try system.configure(cliOpts: [
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*jpg"))",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*png"))",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*png"))",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*bmp"))",
        ])
        XCTAssertEqual(3, TestLogger.shared.diagsBuf.count)
        XCTAssertEqual(2, system.gen.media.mediaFiles.count)
        XCTAssertEqual("media/one.jpg", system.gen.media.urlPathForMedia(filename: "one.jpg"))
        XCTAssertEqual("media/two.png", system.gen.media.urlPathForMedia(filename: "two.png"))
        XCTAssertNil(system.gen.media.urlPathForMedia(filename: "one.png"))

        let dstDir = try tmpDir.createDirectory()
        let dstMediaURL = dstDir.directoryURL.appendingPathComponent("media")
        var filenames = Set(["one.jpg", "two.png"])
        try system.gen.media
            .copyMedia(docRoot: dstDir.directoryURL, languageTag: "en") { from, to in
                let filename = from.lastPathComponent
                XCTAssertTrue(FileManager.default.fileExists(atPath: from.path))
                XCTAssertEqual(filename, filenames.remove(filename))
                XCTAssertEqual(dstMediaURL.appendingPathComponent(filename).path, to.path)
        }
        XCTAssertTrue(filenames.isEmpty)
    }

    // MARK: Search

    #if os(macOS)
    func testSearchGen() throws {
        let clas = SourceKittenDict
            .mkObjCClass(name: "OClass", swiftName: "SClass")
            .with(swiftDeclaration: "class SClass")
        let passes = SourceKittenDict.mkFile().with(children: [clas]).asGatherPasses

        let config = Config()
        let merge = Merge(config: config)
        let group = Group(config: config)
        let format = Format(config: config)
        let gen = GenSite(config: config)
        try config.processOptions(cliOpts: [])
        let items = try format.format(items: group.group(merged: merge.merge(gathered: passes)))
        gen.search.buildIndex(items: items)
        
        XCTAssertEqual(2, gen.search.entries.count)
        XCTAssertEqual("OClass", gen.search.entries[0].name)
        XCTAssertEqual("SClass", gen.search.entries[1].name)
    }
    #endif
}
