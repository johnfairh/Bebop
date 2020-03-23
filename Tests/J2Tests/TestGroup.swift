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
        XCTAssertEqual(ItemKind.type.name.slugged, groups[0].slug)
        XCTAssertEqual("Types", groups[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual(2, groups[0].children.count)
        XCTAssertEqual("C1", groups[0].children[0].name)
        XCTAssertEqual("c1", groups[0].children[0].slug)
        XCTAssertEqual(ItemKind.variable.name.slugged, groups[1].slug)
        XCTAssertEqual(1, groups[1].children.count)
    }

    // Multi-module

    func testMultiModule() throws {
        let system = System()

        let class1 = SourceKittenDict.mkClass(name: "C1")
        let moduleA = SourceKittenDict.mkFile().with(children: [class1]).asGatherDef().asPass(moduleName: "ModuleA")
        let class2 = SourceKittenDict.mkClass(name: "C2")
        let moduleB = SourceKittenDict.mkFile().with(children: [class2]).asGatherDef().asPass(moduleName: "ModuleB")
        let class3 = SourceKittenDict.mkClass(name: "C3")
        let moduleC = SourceKittenDict.mkFile().with(children: [class3]).asGatherDef().asPass(moduleName: "ModuleC")

        // separate

        system.config.published.moduleGroupPolicy = ["ModuleA": .separate, "ModuleB": .separate]
        let groups = try system.run([moduleA, moduleB])

        XCTAssertEqual(2, groups.count)
        XCTAssertEqual("ModuleA Types", groups[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("ModuleB Types", groups[1].titlePreferring(language: .swift).get("en"))

        // global

        system.config.published.moduleGroupPolicy = ["ModuleA": .global, "ModuleB": .global]
        let groups2 = try system.run([moduleA, moduleB])

        XCTAssertEqual(1, groups2.count)
        XCTAssertEqual("Types", groups2[0].titlePreferring(language: .swift).get("en"))

        // separate + global (requires custom categories in reality)

        system.config.published.moduleGroupPolicy = ["ModuleA": .global, "ModuleB": .separate]
        let groups3 = try system.run([moduleA, moduleB])

        XCTAssertEqual(2, groups3.count)
        XCTAssertEqual("ModuleB Types", groups3[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("Types", groups3[1].titlePreferring(language: .swift).get("en"))

        // custom

        system.config.published.moduleGroupPolicy = [
            "ModuleA" : .group(.init(unlocalized: "Fred")),
            "ModuleB": .group(.init(unlocalized: "Fred")),
            "ModuleC": .group(.init(unlocalized: "Barney"))
        ]
        let groups4 = try system.run([moduleA, moduleB, moduleC])

        XCTAssertEqual(2, groups4.count)
        XCTAssertEqual("Barney Types", groups4[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("Fred Types", groups4[1].titlePreferring(language: .swift).get("en"))
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
        XCTAssertEqual("GuideA", guides[0].name)
        XCTAssertEqual(Markdown("A1"), guides[0].content.markdown["en"])
        XCTAssertEqual("GuideB", guides[1].name)
    }

    // Custom

    private func buildCustomGroups(_ yaml: String) throws -> [GroupCustom.Group] {
        let tmpFileURL = FileManager.default.temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tmpFileURL) }
        try yaml.write(to: tmpFileURL)
        let config = Config()
        let group = Group(config: config)
        try config.processOptions(cliOpts: ["--config=\(tmpFileURL.path)"])
        return group.groupCustom.groups
    }

    func testCustomParseGroups() throws {
        let yaml = """
                    custom_groups:
                      - name: Group1
                        children:
                          - G1.C1
                          - G1.C2
                      - name: Group2
                        abstract: Group2Abstract
                      - name: Group3
                        children:
                          - name: Group3.SubGroup
                            children:
                              - G3.S.C1
                    """
        let groups = try buildCustomGroups(yaml)
        print(groups)
        XCTAssertEqual(3, groups.count)
        XCTAssertEqual(.init(unlocalized: "Group1"), groups[0].name)
        XCTAssertEqual(.init(unlocalized: "Group2"), groups[1].name)
        XCTAssertEqual(.init(unlocalized: "Group3"), groups[2].name)
        XCTAssertEqual(GroupCustom.Group.Children.items([.name("G1.C1"), .name("G1.C2")]), groups[0].children)
        XCTAssertNil(groups[0].abstract)
        XCTAssertNil(groups[1].children)
        XCTAssertNotNil(groups[1].abstract)
        let nestGroup = GroupCustom.Group(name: .init(unlocalized: "Group3.SubGroup"),
                                          abstract: nil,
                                          children: .items([.name("G3.S.C1")]))
        XCTAssertEqual(GroupCustom.Group.Children.items([.group(nestGroup)]), groups[2].children)
    }

    func testCustomParseTopics() throws {
        let yaml = """
                   custom_groups:
                   - name: Group
                     skip_unlisted: true
                     topics:
                     - name: Tpc1
                       children:
                         - G.T.1
                         - G.T.2
                     - name: Tpc2
                       abstract: Empty
                   """
        let groups = try buildCustomGroups(yaml)
        print(groups)
        XCTAssertEqual(1, groups.count)
        let topic1 = GroupCustom.Group.Topic(name: .init(unlocalized: "Tpc1"),
                                             abstract: nil,
                                             children: [.name("G.T.1"), .name("G.T.2")])
        let topic2 = GroupCustom.Group.Topic(name: .init(unlocalized: "Tpc2"),
                                             abstract: .init(unlocalized: "Empty"),
                                             children: [])
        XCTAssertEqual(.init(unlocalized: "Group"), groups[0].name)
        XCTAssertNil(groups[0].abstract)
        XCTAssertEqual(GroupCustom.Group.Children.topics([topic1, topic2], true), groups[0].children)
    }

    func checkCustomParseError(_ yaml: String) {
        AssertThrows(try buildCustomGroups(yaml), OptionsError.self)
    }

    func testCustomParseErrors() throws {
        let noNameGroup = "custom_groups:\n - abstract: Fred"
        checkCustomParseError(noNameGroup)

        let bothChildTypes = """
                             custom_groups:
                              - name: G
                                children:
                                   - C
                                topics:
                                   - C
                             """
        checkCustomParseError(bothChildTypes)

        let badSkipUnlisted = """
                              custom_groups:
                               - name: G
                                 skip_unlisted: true
                                 children:
                                   - C
                              """
       checkCustomParseError(badSkipUnlisted)

        let nestedTopics =  """
                            custom_groups:
                             - name: G
                               topics:
                                 - name: T
                                   topics:
                                    - name: TT
                            """
        checkCustomParseError(nestedTopics)
    }
}
