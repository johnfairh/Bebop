//
//  TestGroup.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let merge: Merge
    let group: Group

    init(cliArgs: [String] = []) {
        config = Config()
        merge = Merge(config: config)
        group = Group(config: config)
        try! config.processOptions(cliOpts: cliArgs + ["--min-acl=private"])
    }

    func run(_ passes: [GatherModulePass]) throws -> [Item] {
        let merged = try merge.merge(gathered: passes)
        return try group.group(merged: merged)
    }
}

class TestGroup: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testEmpty() throws {
        let system = System()
        XCTAssertTrue(try system.run([]).isEmpty)
    }

    func testByKind() throws {
        let system = System()

        let class1 = SourceKittenDict.mkClass(name: "C1")
        let class2 = SourceKittenDict.mkClass(name: "C2")
        let globalv = SourceKittenDict.mkGlobalVar(name: "GV1")
        let file = SourceKittenDict.mkFile()
            .with(children: [class1, class2, globalv])

        let groups = try system.run(file.asGatherPasses)

        XCTAssertEqual(2, groups.count)
        XCTAssertEqual(ItemKind.type.name, groups[0].slug)
        XCTAssertEqual("Types", groups[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual(2, groups[0].children.count)
        XCTAssertEqual("C1", groups[0].children[0].name)
        XCTAssertEqual("c1", groups[0].children[0].slug)
        XCTAssertEqual(ItemKind.variable.name, groups[1].slug)
        XCTAssertEqual(1, groups[1].children.count)
    }

    // Guides

    func testGuides() throws {
        let tmpDir = try TemporaryDirectory()
        let subDir = tmpDir.directoryURL.appendingPathComponent("fr")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: false)
        let filename = "Guide.md"
        try "English".write(to: tmpDir.directoryURL.appendingPathComponent(filename))
        try "French".write(to: subDir.appendingPathComponent(filename))

        let system = System(cliArgs: ["--guides", "\(tmpDir.directoryURL.path)/*"])
        let guides = try system.group.groupGuides.discoverGuides()
        XCTAssertEqual(1, guides.count)
        let guide = guides[0]
        XCTAssertEqual(1, guide.content.markdown.count)
        XCTAssertEqual(Markdown("English"), guide.content.markdown["en"])

        Localizations.shared = Localizations(mainDescriptor: Localization.defaultDescriptor,
                                             otherDescriptors: ["fr:FR:frfrfr"])
        let guides2 = try system.group.groupGuides.discoverGuides()
        XCTAssertEqual(1, guides2.count)
        let guide2 = guides2[0]
        XCTAssertEqual(2, guide2.content.markdown.count)
        XCTAssertEqual(Markdown("English"), guide2.content.markdown["en"])
        XCTAssertEqual(Markdown("French"), guide2.content.markdown["fr"])

        Localizations.shared = Localizations(mainDescriptor: Localization.defaultDescriptor,
                                             otherDescriptors: ["de:DE:dedede"])
        let guides3 = try system.group.groupGuides.discoverGuides()
        XCTAssertEqual(1, guides3.count)
        let guide3 = guides3[0]
        XCTAssertEqual(2, guide3.content.markdown.count)
        XCTAssertEqual(Markdown("English"), guide3.content.markdown["en"])
        XCTAssertEqual(Markdown("English"), guide3.content.markdown["de"])
    }

    func testBadGuides() throws {
        let tmpDir1 = try TemporaryDirectory()
        let tmpDir2 = try TemporaryDirectory()
        try "A1".write(to: tmpDir1.directoryURL.appendingPathComponent("GuideA.md"))
        try "A2".write(to: tmpDir2.directoryURL.appendingPathComponent("GuideA.md"))
        try "B".write(to: tmpDir2.directoryURL.appendingPathComponent("GuideB.md"))

        let system = System(cliArgs: ["--guides", "\(tmpDir1.directoryURL.path)/*,\(tmpDir2.directoryURL.path)/*.md,/*"])
        let guides = try system.group.groupGuides.discoverGuides()
        XCTAssertEqual(2, guides.count)
        XCTAssertEqual("GuideA.md", guides[0].name)
        XCTAssertEqual(Markdown("A1"), guides[0].content.markdown["en"])
        XCTAssertEqual("GuideB.md", guides[1].name)
    }
}
