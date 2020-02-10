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

extension GenData {
    convenience init() {
        self.init(meta: Meta(version: "TEST"), toc: [], pages: [])
    }
}

class TestGen: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testCreateOutputDir() throws {
        let fm = FileManager.default
        let outputDir = fm.temporaryFileURL()
        XCTAssertFalse(fm.fileExists(atPath: outputDir.path))
        let system = System()
        try system.configure(cliOpts: ["--output", outputDir.path])
        try system.gen.generate(genData: GenData())
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
        try system.gen.generate(genData: GenData())
        XCTAssertTrue(fm.fileExists(atPath: tmp.directoryURL.path))
        XCTAssertFalse(fm.fileExists(atPath: markerFileURL.path))
    }

    func testPageGen() throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        TestLogger.install()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--products", "docs-summary-json"])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count)

        let spmTestDocsSummaryJsonURL = fixturesURL.appendingPathComponent("SpmSwiftModule.docs-summary.json")

        let actualJson = TestLogger.shared.outputBuf[0] + "\n"

        // to fix up when it changes...
        // try actualJson.write(to: spmTestDocsSummaryJsonURL)

        let expectedJson = try String(contentsOf: spmTestDocsSummaryJsonURL)
        XCTAssertEqual(expectedJson, actualJson)
    }

    // Page-Gen iterator

    private func mkPage(_ name: String) -> GenData.Page {
        var title = Localized<String>()
        Localizations.shared.allTags.forEach {
            title[$0] = "\($0)-\(name)"
        }
        return GenData.Page(url: URLPieces(pageName: name), title: title)
    }

    func testPageGenIterator() throws {
        let meta = GenData.Meta(version: "")

        Localizations.shared = Localizations(main: Localization.default)
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
        let meta = GenData.Meta(version: "")

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
        let it_3 = it.next()
        XCTAssertEqual("fr", it_3?.languageTag)
        XCTAssertEqual("fr-page1", it_3?.data[.pageTitle] as? String)
        let it_4 = it.next()
        XCTAssertEqual("fr-page2", it_4?.data[.pageTitle] as? String)
        XCTAssertNil(it.next())
    }
}
