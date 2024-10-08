//
//  TestGen.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif // wtf
import XCTest
@testable import BebopLib

fileprivate struct System {
    let config: Config
    let genPages: GenPages
    let gen: GenSite

    init(fakeMedia: Bool = false) {
        config = Config()
        genPages = GenPages(config: config)
        gen = GenSite(config: config)
        if fakeMedia {
            gen.media.fakeMediaLookup = true
        }
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
        return GenData.Page(guideURL: URLPieces(pathComponents: [name]),
                            title: title, breadcrumbs: [],
                            isReadme: false,
                            content: nil,
                            topics: [:],
                            pagination: GenData.Pagination(prev: nil, next: nil),
                            codeHostURL: nil)
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

    func testGlobalData() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-attribution", "--no-hide-search"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        XCTAssertEqual(Version.bebopLibVersion, globalData[.bebopLibVersion] as? String)
        XCTAssertEqual(false, globalData[.hideSearch] as? Bool)
        XCTAssertEqual(true, globalData[.hideAttribution] as? Bool)
        XCTAssertEqual(0, globalData[.docCoverage] as? Int)
        XCTAssertNil(globalData[.customHead])
    }

    func testHideCoverage() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-documentation-coverage"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        XCTAssertNil(globalData[.docCoverage])
    }

    func testHideActions() throws {
        let system = System()
        try system.configure(cliOpts: ["--hide-search", "--nested-item-style=always-open"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        XCTAssertEqual(true, globalData[.hideActions] as? Bool)
    }

    private func checkTitles(_ cliOpts: [String], _ modules: [String],
                             _ title: String?, _ bcRoot: String, line: UInt = #line) throws {
        let system = System()
        try system.configure(cliOpts: cliOpts)
        system.config.test_publishStore.modules = modules.map {
            PublishedModule(name: $0, groupPolicy: .separate)
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
                XCTAssertTrue(html.value.contains(match), html.value, line: line)
            }
        }
    }

    func testCopyright() throws {
        /* Check auto path doesn't crash */
        try checkCopyright(cliArgs: [], langMatches: ["en": ["©"]])
        setenv("BEBOP_STATIC_DATE", strdup("1") /* leak it */, 1)
        defer { unsetenv("BEBOP_STATIC_DATE") }
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
        system.config.test_publishStore.defaultLanguage = .objc
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
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*jpg").path)",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*png").path)",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*png").path)",
            "--media=\(tmpDir.directoryURL.appendingPathComponent("*bmp").path)",
        ])
        XCTAssertEqual(3, TestLogger.shared.diagsBuf.count)
        XCTAssertEqual(2, system.gen.media.mediaFiles.count)
        XCTAssertEqual("media/one.jpg", system.gen.media.urlPathForMedia(filename: "one.jpg"))
        XCTAssertEqual("media/two.png", system.gen.media.urlPathForMedia(filename: "two.png"))
        XCTAssertNil(system.gen.media.urlPathForMedia(filename: "one.png"))

        let dstDir = try tmpDir.createDirectory()
        let dstMediaURL = dstDir.directoryURL.appendingPathComponent("media")

        try system.gen.media.copyMedia(docRoot: dstDir.directoryURL, languageTag: "en")
        ["one.jpg", "two.png"].forEach { filename in
            let dstURL = dstMediaURL.appendingPathComponent(filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: dstURL.path))
        }
    }

    // MARK: Search

    struct FullSystem {
        let config: Config
        let merge: Merge
        let group: Group
        let format: Format
        let pageGen: GenPages
        let gen: GenSite

        init() {
            config = Config()
            merge = Merge(config: config)
            group = Group(config: config)
            format = Format(config: config)
            pageGen = GenPages(config: config)
            gen = GenSite(config: config)
        }

        func makeItems(cliOpts: [String] = [], passes: [GatherModulePass] = []) throws -> [Item] {
            try config.processOptions(cliOpts: cliOpts)
            config.test_publishStore.modules = passes.map { PublishedModule(name: $0.moduleName) }
            return try format.format(items: group.group(merged: merge.merge(gathered: passes)))
        }

        func makePageData(cliOpts: [String] = [], passes: [GatherModulePass] = []) throws -> GenData {
            return try pageGen.generatePages(items: makeItems(cliOpts: cliOpts, passes: passes))
        }
    }

    #if os(macOS)
    /// Just an interesting-path test, covered in TestProducts
    func testSearchGen() throws {
        let clas = SourceKittenDict
            .mkObjCClass(name: "OClass", swiftName: "SClass")
            .with(swiftDeclaration: "class SClass")
        let passes = SourceKittenDict.mkFile().with(children: [clas]).asGatherPasses

        let system = FullSystem()
        let items = try system.makeItems(passes: passes)
        try system.gen.search.buildIndex(items: items)
        
        XCTAssertEqual(2, system.gen.search.entries.count)
        XCTAssertEqual("OClass", system.gen.search.entries[0].name)
        XCTAssertEqual("SClass", system.gen.search.entries[1].name)
    }
    #endif

    // MARK: Pagination

    func testPagination() throws {
        let system = FullSystem()
        let data = try system.makePageData(cliOpts: ["--hide-pagination"])
        system.gen.generatePages(genData: data, fileExt: ".html") { loc, dict, tag in
            XCTAssertNil(dict[MustacheKey.pagination.rawValue])
        }
    }

    // MARK: Brand

    private func checkConfigError(yaml: String, fakeMedia: Bool = false, args: [String] = [], _ key: L10n.Localizable) throws {
        let system = System(fakeMedia: fakeMedia)
        let cfgFileURL = FileManager.default.temporaryFileURL()
        try yaml.write(to: cfgFileURL)
        AssertThrows(try system.configure(cliOpts: ["--config=\(cfgFileURL.path)"] + args), key)
    }

    /// Bad-path again, covered in LayoutTest
    func testBrandConfigErrors() throws {
        let missingImg = "custom_brand:\n  alt_text: Fred\n"
        try checkConfigError(yaml: missingImg, .errCfgBrandMissingImage)

        let badImg = "custom_brand:\n  image_name: Fred\n"
        try checkConfigError(yaml: badImg, .errCfgBrandBadImage)
    }

    // MARK: CodeHost

    // full yaml
    func testCodeHostYaml() throws {
        let yaml =
        """
        custom_code_host:
          image_name: fred
          alt_text:
            en: barney
            fr: le rubble
          title:
            en: wilma
            fr: la rubble
          single_line_format: "L%LINE"
          multi_line_format: "LL%LINE1:%LINE2"
          item_menu_text:
            en: See the code
        """
        let system = System(fakeMedia: true)
        let cfgFileURL = FileManager.default.temporaryFileURL()
        try yaml.write(to: cfgFileURL)
        try system.configure(cliOpts: ["--config=\(cfgFileURL.path)"])
        XCTAssertEqual("See the code", system.gen.codeHost.defLinkText.get("en"))
    }

    /// Yaml config errors
    func testCodeHostConfigErrors() throws {
        let missingImg = "custom_code_host:\n  alt_text: fred"
        try checkConfigError(yaml: missingImg, .errCfgChostMissingImage)

        let badImg = "custom_code_host:\n  image_name: fred"
        try checkConfigError(yaml: badImg, .errCfgChostBadImage)

        let badSingle = "custom_code_host:\n  image_name: fred\n  single_line_format: line"
        try checkConfigError(yaml: badSingle, fakeMedia: true, .errCfgChostSingleFmt)

        let badMulti1 = "custom_code_host:\n  image_name: fred\n  multi_line_format: L%LINE1"
        try checkConfigError(yaml: badMulti1, fakeMedia: true, .errCfgChostMultiFmt)

        let badMulti2 = "custom_code_host:\n  image_name: fred\n  multi_line_format: L%LINE2"
        try checkConfigError(yaml: badMulti2, fakeMedia: true, .errCfgChostMultiFmt)

        let badCustom = "custom_code_host:\n  image_name: fred\n  multi_line_format: L%LINE1-L%LINE2"
        try checkConfigError(yaml: badCustom, fakeMedia: true, .errCfgChostMissingFmt)

        let minimal = "custom_code_host:\n  image_name: fred"
        try checkConfigError(yaml: minimal, fakeMedia: true, args: ["--code-host=bitbucket"], .errCfgChostBoth)
    }

    func testCodehosts() throws {
        try CodeHost.allCases.forEach { codehost in
            let system = System()
            try system.configure(cliOpts: ["--code-host=\(codehost.rawValue)"])
            let globalData = system.gen.buildGlobalData(genData: GenData())
            XCTAssertEqual(true, globalData["codehost_\(codehost.rawValue)"] as? Bool)
            let linkText = system.gen.codeHost.defLinkText.get("en")
            XCTAssertTrue(linkText.lowercased().contains(codehost.rawValue))
        }
    }

    func testCodeHostLineFormatter() throws {
        let ghFormatter = GitHubLineFormatter()
        XCTAssertNil(ghFormatter.format(startLine: nil, endLine: 5))

        XCTAssertEqual("L100", ghFormatter.format(startLine: 100, endLine: nil))
        XCTAssertEqual("L100", ghFormatter.format(startLine: 100, endLine: 100))
        XCTAssertEqual("L100-L105", ghFormatter.format(startLine: 100, endLine: 105))

        let bbFormatter = BitBucketLineFormatter()
        XCTAssertEqual("lines-100", bbFormatter.format(startLine: 100, endLine: nil))
        XCTAssertEqual("lines-100", bbFormatter.format(startLine: 100, endLine: 100))
        XCTAssertEqual("lines-100:105", bbFormatter.format(startLine: 100, endLine: 105))
    }

    // MARK: Docset

    private func createDocset(_ args: [String], verify: (URL) throws -> ()) throws {
        let tempDir = try TemporaryDirectory()
        let fullArgs = [
            "--source-directory", fixturesURL.appendingPathComponent("SpmSwiftPackage").path,
            "--module=SpmSwiftModule2",
            "--output", tempDir.directoryURL.path,
            "--products=docs,docset"
        ]
        try Pipeline().run(argv: fullArgs + args)
        try verify(tempDir.directoryURL)
    }

    func testDocsetErrors() throws {
        let badIcon = """
                      docset_icon_2x: \(fixturesURL.appendingPathComponent("SpmSwiftModule.files.json").path)
                      """
        try checkConfigError(yaml: badIcon, .errCfgDocsetIcon)
    }

    func testDocsetWarning() throws {
        TestLogger.install()
        try createDocset(["--docset-path=Fred"]) { _ in
        }
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    func testDocsetModule() throws {
        try createDocset(["--docset-module-name=GoodName"]) { url in
            let expectedURL = url.appendingPathComponent("docsets")
                .appendingPathComponent("GoodName.docset")
            XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))
        }
    }

    func testDocsetPlist() throws {
        let playURLString = "https://foo.com/"
        let extURLString = "https://bar.com/"
        try createDocset(["--docset-playground-url", playURLString,
                          "--deployment-url", extURLString]) { url in
            let plistURL = url.appendingPathComponent("docsets/SpmSwiftModule2.docset/Contents/Info.plist")
            let plistData = try Data(contentsOf: plistURL)

            guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String:Any] else {
                XCTFail("Couldn't load plist: \(plistURL.path)")
                return
            }
            guard let playKeyVal = plist["DashDocSetPlayURL"] as? String else {
                XCTFail("Couldn't find play key in plist: \(plist)")
                return
            }
            XCTAssertEqual(playURLString, playKeyVal)

            guard let extKeyVal = plist["DashDocSetFallbackURL"] as? String else {
                XCTFail("Couldn't find ext key in plist: \(plist)")
                return
            }
            XCTAssertEqual(extURLString, extKeyVal)
        }
    }

    func testDocsetIcons() throws {
        let tmpDir = try TemporaryDirectory()
        let icon1URL = tmpDir.directoryURL.appendingPathComponent("inputicon1.png")
        let icon2URL = tmpDir.directoryURL.appendingPathComponent("inputicon2.png")
        try "icon1".write(to: icon1URL)
        try "icon2".write(to: icon2URL)
        try createDocset([
            "--docset-icon", icon1URL.path,
            "--docset-icon-2x", icon2URL.path
        ]) { url in
            func check(_ url: URL, _ expected: String) throws {
                let actual = try String(contentsOf: url, encoding: .utf8)
                XCTAssertEqual(expected, actual)
            }
            try check(url.appendingPathComponent("docsets/SpmSwiftModule2.docset/icon.png"), "icon1")
            try check(url.appendingPathComponent("docsets/SpmSwiftModule2.docset/icon@2x.png"), "icon2")
        }
    }

    func testDocsetXml() throws {
        let version = "2.4"
        let deploymentURLString = "http://www.foo.com/docs"
        try createDocset([
            "--deployment-url", deploymentURLString,
            "--module-version", version
        ]) { url in
            let xmlURL = url.appendingPathComponent("docsets/SpmSwiftModule2.xml")
            let xml = try String(contentsOf: xmlURL, encoding: .utf8)
            let parser = XMLParser(data: xml.data(using: .utf8)!)
            XCTAssertTrue(parser.parse())
            XCTAssertTrue(xml.contains("<version>\(version)</version>"))
            XCTAssertTrue(xml.contains("<url>\(deploymentURLString)/docsets/SpmSwiftModule2.tgz</url>"))
        }
    }

    func testDocsetURL() throws {
        let system = System()
        try system.configure(cliOpts: ["--deployment-url=https://www.google.com/docs/", "--docset-module-name=Fred"])
        let globalData = system.gen.buildGlobalData(genData: GenData())
        guard let docsetURL = globalData[.docsetURL] as? String else {
            XCTFail()
            return
        }
        XCTAssertTrue(docsetURL.hasPrefix("dash-feed://"))
        XCTAssertEqual("https://www.google.com/docs/docsets/Fred.xml",
                       docsetURL.dropFirst("dash-feed://".count).removingPercentEncoding)
    }

    // MARK: Theme copy

    private func doCopyTheme(args: [String] = [], verify: (URL) throws -> ()) throws {
        let tmpDir = try TemporaryDirectory()
        let system = System()
        try system.configure(cliOpts: ["--output", tmpDir.directoryURL.path] + args)
        try system.gen.copyTheme()
        try verify(tmpDir.directoryURL)
    }

    func testThemeCopy() throws {
        try doCopyTheme { outputURL in
            // just sniff some
            ["assets", "templates", "templates/doc.mustache", "assets/css/fw2020.css"].forEach {
                XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.appendingPathComponent($0).path), $0)
            }
        }
    }
}
