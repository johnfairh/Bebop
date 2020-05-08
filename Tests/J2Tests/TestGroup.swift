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
        if config.published.modules.isEmpty {
            config.test_publishStore.modules = passes.map { PublishedModule(name: $0.moduleName) }
        }
        let merged = try merge.merge(gathered: passes)
        return try group.group(merged: merged)
    }
}

class TestGroup: XCTestCase {
    override func setUp() {
        initResources()
    }

    // MARK: By Kind

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

    // MARK: MultiModule

    func testMultiModule() throws {
        let system = System()

        let class1 = SourceKittenDict.mkClass(name: "C1")
        let moduleA = SourceKittenDict.mkFile().with(children: [class1]).asGatherDef().asPass(moduleName: "ModuleA")
        let class2 = SourceKittenDict.mkClass(name: "C2")
        let moduleB = SourceKittenDict.mkFile().with(children: [class2]).asGatherDef().asPass(moduleName: "ModuleB")
        let class3 = SourceKittenDict.mkClass(name: "C3")
        let moduleC = SourceKittenDict.mkFile().with(children: [class3]).asGatherDef().asPass(moduleName: "ModuleC")

        // separate

        system.config.test_publishStore.modules = [
            PublishedModule(name: "ModuleA", groupPolicy: .separate),
            PublishedModule(name: "ModuleB", groupPolicy: .separate),
        ]
        let groups = try system.run([moduleA, moduleB])

        XCTAssertEqual(2, groups.count)
        XCTAssertEqual("ModuleA Types", groups[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("ModuleB Types", groups[1].titlePreferring(language: .swift).get("en"))

        // global

        system.config.test_publishStore.modules = [
            PublishedModule(name: "ModuleA", groupPolicy: .global),
            PublishedModule(name: "ModuleB", groupPolicy: .global),
        ]
        let groups2 = try system.run([moduleA, moduleB])

        XCTAssertEqual(1, groups2.count)
        XCTAssertEqual("Types", groups2[0].titlePreferring(language: .swift).get("en"))

        // separate + global (requires custom categories in reality)

        system.config.test_publishStore.modules = [
            PublishedModule(name: "ModuleA", groupPolicy: .global),
            PublishedModule(name: "ModuleB", groupPolicy: .separate),
        ]
        let groups3 = try system.run([moduleA, moduleB])

        XCTAssertEqual(2, groups3.count)
        XCTAssertEqual("ModuleB Types", groups3[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("Types", groups3[1].titlePreferring(language: .swift).get("en"))

        // custom

        system.config.test_publishStore.modules = [
            PublishedModule(name: "ModuleA", groupPolicy: .group(.init(unlocalized: "Fred"))),
            PublishedModule(name: "ModuleB", groupPolicy: .group(.init(unlocalized: "Fred"))),
            PublishedModule(name: "ModuleC", groupPolicy: .group(.init(unlocalized: "Barney")))
        ]
        let groups4 = try system.run([moduleA, moduleB, moduleC])

        XCTAssertEqual(2, groups4.count)
        XCTAssertEqual("Barney Types", groups4[0].titlePreferring(language: .swift).get("en"))
        XCTAssertEqual("Fred Types", groups4[1].titlePreferring(language: .swift).get("en"))
    }

    // MARK: Guides

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

    // MARK: Custom Groups

    private func withTempConfigFile<T>(yaml: String, callback: (URL) throws -> T) throws -> T{
        let tmpFileURL = FileManager.default.temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: tmpFileURL) }
        try yaml.write(to: tmpFileURL)
        return try callback(tmpFileURL)
    }

    private func buildCustomGroups(_ yaml: String) throws -> [GroupCustom.Group] {
        try withTempConfigFile(yaml: yaml) { url in
            let config = Config()
            let group = Group(config: config)
            try config.processOptions(cliOpts: ["--config=\(url.path)"])
            return group.groupCustom.groups
        }
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
                        mix_languages: no
                      - name: Group3
                        children:
                          - name: Group3.SubGroup
                            children:
                              - G3.S.C1
                    """
        let groups = try buildCustomGroups(yaml)
        XCTAssertEqual(3, groups.count)
        XCTAssertEqual(.init(unlocalized: "Group1"), groups[0].name)
        XCTAssertTrue(groups[0].mixLanguages)
        XCTAssertEqual(.init(unlocalized: "Group2"), groups[1].name)
        XCTAssertFalse(groups[1].mixLanguages)
        XCTAssertEqual(.init(unlocalized: "Group3"), groups[2].name)
        XCTAssertTrue(groups[2].mixLanguages)
        XCTAssertEqual([.init(topic: Topic(), children: [.name("G1.C1"), .name("G1.C2")])], groups[0].topics)
        XCTAssertNil(groups[0].abstract)
        XCTAssertTrue(groups[1].topics.isEmpty)
        XCTAssertNotNil(groups[1].abstract)
        let nestGroup = GroupCustom.Group(name: .init(unlocalized: "Group3.SubGroup"),
                                          abstract: nil,
                                          mixLanguages: true,
                                          topics: [.init(topic: Topic(), children: [.name("G3.S.C1")])])
        XCTAssertEqual(.init(topic: Topic(), children: [.group(nestGroup)]), groups[2].topics[0])
    }

    func testCustomParseTopics() throws {
        let yaml = """
                   custom_groups:
                   - name: Group
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
        let topic1 = GroupCustom.Group.Topic(topic: Topic(title: .init(unlocalized: "Tpc1")),
                                             children: [.name("G.T.1"), .name("G.T.2")])
        let topic2 = GroupCustom.Group.Topic(topic: Topic(title: .init(unlocalized: "Tpc2"),
                                                          overview: .init(unlocalized: "Empty")),
                                             children: [])
        XCTAssertEqual(.init(unlocalized: "Group"), groups[0].name)
        XCTAssertNil(groups[0].abstract)
        XCTAssertEqual(topic1, groups[0].topics[0])
        XCTAssertEqual(topic2, groups[0].topics[1])
    }

    func checkCustomParseError(_ yaml: String, _ key: L10n.Localizable) {
        AssertThrows(try buildCustomGroups(yaml), key)
    }

    func testCustomParseErrors() throws {
        let noNameGroup = "custom_groups:\n - abstract: Fred"
        checkCustomParseError(noNameGroup, .errCfgCustomGrpName)

        let bothChildTypes = """
                             custom_groups:
                              - name: G
                                children:
                                   - C
                                topics:
                                   - C
                             """
        checkCustomParseError(bothChildTypes, .errCfgCustomGrpBoth)

        let badSkipUnlisted = """
                              custom_groups:
                               - name: G
                                 skip_unlisted: true
                                 children:
                                   - C
                              """
       checkCustomParseError(badSkipUnlisted, .errCfgBadKey)

        let nestedTopics =  """
                            custom_groups:
                             - name: G
                               topics:
                                 - name: T
                                   topics:
                                    - name: TT
                            """
        checkCustomParseError(nestedTopics, .errCfgCustomGrpNested)
    }

    func testCustomGroupBuilder() throws {
        let class1 = SourceKittenDict.mkClass(name: "Class1")
        let class2 = SourceKittenDict.mkClass(name: "Class2")
        let class3 = SourceKittenDict.mkClass(name: "Class3")
        let file = SourceKittenDict.mkFile().with(children: [class1, class2, class3])

        let yaml = """
                    custom_groups:
                      - name: CGroup
                        children:
                          - Class1
                          - Closs1
                          - name: Nested
                            children:
                              - Module.Class3
                    """
        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            TestLogger.install()
            let items = try system.run([file.asGatherDef().asPass(moduleName: "Module", pathName: "")])
            XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

            XCTAssertEqual(2, items.count)
            XCTAssertEqual("CGroup", items[0].name)
            XCTAssertEqual(2, items[0].children.count)
            XCTAssertEqual("Class1", items[0].children[0].name)
            XCTAssertEqual("Nested", items[0].children[1].name)
            XCTAssertEqual(1, items[0].children[1].children.count)
            XCTAssertEqual("Class3", items[0].children[1].children[0].name)
            XCTAssertEqual("Types", items[1].name)
            XCTAssertEqual(1, items[1].children.count)
            XCTAssertEqual("Class2", items[1].children[0].name)
        }
    }

    // MARK: Unlisted Prefix

    func testCustomPrefix() throws {
        let class1 = SourceKittenDict.mkClass(name: "Class1")
        let class2 = SourceKittenDict.mkClass(name: "Class2")
        let file = SourceKittenDict.mkFile().with(children: [class1, class2])

        let yaml = """
                   custom_groups:
                     - name: Grp
                       children:
                          - Class1

                   custom_groups_unlisted_prefix: Other
                   """

        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            let items = try system.run(file.asGatherPasses)

            XCTAssertEqual(2, items.count)
            XCTAssertEqual("Grp", items[0].name)
            XCTAssertEqual("Other Types", items[1].name)
        }
    }

    // MARK: Excluded unlisted

    func testExcludeUnlistedGuides() throws {
        let tmpDir = try TemporaryDirectory()
        try "G1".write(to: tmpDir.directoryURL.appendingPathComponent("Guide1.md"))
        try "G2".write(to: tmpDir.directoryURL.appendingPathComponent("Guide2.md"))

        let yaml = """
                   custom_groups:
                    - name: Grp
                      children:
                        - Guide1

                   exclude_unlisted_guides: true
                   """

        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: [
                "--guides=\(tmpDir.directoryURL.path)/*md",
                "--config=\(url.path)"
            ])
            let items = try system.run(SourceKittenDict.mkFile().asGatherPasses)
            XCTAssertEqual(1, items.count)
            XCTAssertEqual(1, items[0].children.count)
            XCTAssertEqual("Guide1", items[0].children[0].name)
        }
    }

    // MARK: Custom Defs

    // Leftovers, by-source-order, new topic
    func testCustomDefs() throws {
        let method1 = SourceKittenDict.mkMethod(fullName: "fn(a:)", decl: "func fn(a: Int)")
        let method2 = SourceKittenDict.mkMethod(fullName: "fn(a:)", decl: "func fn(a: String)")
        let method3 = SourceKittenDict.mkMethod(fullName: "fn2()", decl: "func fn2()")
        let class1 = SourceKittenDict
            .mkClass(name: "NestedClass")
            .with(children: [method1, method2, method3])
        let class2 = SourceKittenDict.mkClass(name: "ParentClass").with(children: [class1])
        let file = SourceKittenDict.mkFile().with(children: [class2])
        let passes = [file.asGatherDef().asPass(moduleName: "Module", pathName: "")]

        // Most goodpath features

        let yaml = """
                   custom_defs:
                     - name: ParentClass.NestedClass
                       topics:
                         - name: Topic1
                           abstract: Topic1 Abstract
                           children:
                             - fn2()
                             - "func fn(a: String)"
                             - missing
                     - name: ParentClass.NestedClass
                       topics:
                         - name: Capricorn
                     - name: Module.ParentClass
                       topics:
                         - name: PTopic1
                           children:
                             - NestedClass
                   """
        try withTempConfigFile(yaml: yaml) { url in
            TestLogger.install()

            let system = System(cliArgs: ["--config=\(url.path)"])
            print(system.group.groupCustom.defs)
            let tpc1 = Topic(title: .init(unlocalized: "Topic1"), overview: .init(unlocalized: "Topic1 Abstract"))
            let def1 = GroupCustom.Def(name: "ParentClass.NestedClass", skipUnlisted: false, topics: [
                .init(topic: tpc1, children: ["fn2()", "func fn(a: String)", "missing"])
                ])
            let tpc2 = Topic(title: .init(unlocalized: "PTopic1"))
            let def2 = GroupCustom.Def(name: "Module.ParentClass", skipUnlisted: false, topics: [
                .init(topic: tpc2, children: ["NestedClass"])
                ])
            let parsedDefs = system.group.groupCustom.defs.values.sorted(by: { $0.name >= $1.name })
            XCTAssertEqual(def1, parsedDefs[0])
            XCTAssertEqual(def2, parsedDefs[1])

            let items = try system.run(passes)

            // warnings about repeated def & unmatched 'missing'
            XCTAssertEqual(2, TestLogger.shared.diagsBuf.count)

            XCTAssertEqual(1, items.count)
            XCTAssertEqual("ParentClass", items[0].children[0].name)
            let nestedClass = items[0].children[0].children[0] as! DefItem
            XCTAssertEqual(tpc2, nestedClass.topic)
            XCTAssertEqual(3, nestedClass.children.count)
            XCTAssertEqual("func fn2()", nestedClass.defChildren[0].primaryNamePieces.flattened)
            XCTAssertEqual(tpc1, nestedClass.defChildren[0].topic)
            XCTAssertEqual("func fn(a: String)", nestedClass.defChildren[1].primaryNamePieces.flattened)
            XCTAssertEqual(tpc1, nestedClass.defChildren[1].topic)
            XCTAssertEqual("Methods", nestedClass.defChildren[2].topic?.title.plainText.first!.value)
            XCTAssertEqual("func fn(a: Int)", nestedClass.defChildren[2].primaryNamePieces.flattened)
        }

    }

    func testCustomDefSkipUnlisted() throws {
        let method1 = SourceKittenDict.mkMethod(fullName: "fn(a:)", decl: "func fn(a: Int)")
        let method2 = SourceKittenDict.mkMethod(fullName: "fn2()", decl: "func fn2()")
        let class1 = SourceKittenDict
            .mkClass(name: "Class")
            .with(children: [method1, method2])
        let file = SourceKittenDict.mkFile().with(children: [class1])

        let yaml2 = """
                    custom_defs:
                      - name: Class
                        skip_unlisted: true
                        topics:
                        - name: Topic1
                          children:
                            - fn2()
                    """

        try withTempConfigFile(yaml: yaml2) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            let items = try system.run(file.asGatherPasses)
            XCTAssertEqual(1, items[0].children[0].children.count)
            XCTAssertEqual("fn2()", items[0].children[0].children[0].name)
        }
    }

    func testCustomDefSourceOrder() throws {
        let method1 = SourceKittenDict.mkMethod(fullName: "fn(a:)", decl: "func fn(a: Int)")
        let method2 = SourceKittenDict.mkMethod(fullName: "fn2()", decl: "func fn2()")
        let class1 = SourceKittenDict
            .mkClass(name: "Class")
            .with(children: [method1, method2])
        let file = SourceKittenDict.mkFile().with(children: [class1])

        let yaml2 = """
                    custom_defs:
                      - name: Class
                        topics:
                        - name: Topic1
                          children:
                            - fn2()
                    """

        try withTempConfigFile(yaml: yaml2) { url in
            let system = System(cliArgs: ["--config=\(url.path)", "--topic-style=source-order"])
            let items = try system.run(file.asGatherPasses)
            XCTAssertEqual(2, items[0].children[0].children.count)
            XCTAssertEqual("Other Definitions", items[0].children[0].children[1].topic?.title.plainText.first!.value)
        }
    }

    func testCustomDefParseErrors() throws {

        let missingDefName = """
                             custom_defs:
                              - skip_unlisted: true
                             """
        checkCustomParseError(missingDefName, .errCfgCustomDefName)

        let missingTopics = """
                            custom_defs:
                              - name: Def1
                                skip_unlisted: false
                            """
        checkCustomParseError(missingTopics, .errCfgCustomDefTopics)

        let missingTopicName = """
                               custom_defs:
                                 - name: Def1
                                   topics:
                                     - children:
                                         - A
                               """
        checkCustomParseError(missingTopicName, .errCfgCustomDefTopicName)
    }

    // MARK: Constrained Extensions

    func testCustomDefConstrainedExtensions() throws {
        let method1 = SourceKittenDict.mkMethod(fullName: "fn(a:)", decl: "func fn(a: Int)")
        let method2 = SourceKittenDict.mkMethod(fullName: "fn2(b:)", decl: "func fn2(b: Int)")
        let ext = SourceKittenDict.mkExtension(name: "Class")
            .with(decl: "extension Class where T: Decodable")
            .with(children: [method1, method2])
        let clas = SourceKittenDict.mkClass(name: "Class")
        let file = SourceKittenDict.mkFile().with(children: [ext, clas])

        let yaml = """
                   custom_defs:
                     - name: Class
                       skip_unlisted: true
                       topics:
                         - name: Things
                           children:
                              - "fn(a:) where T: Decodable"
                              - fn2(b:)
                   """
        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            let items = try system.run(file.asGatherPasses)
            XCTAssertEqual(1, items.count)
            XCTAssertEqual(1, items[0].children[0].children.count)
            XCTAssertEqual("fn(a:)", items[0].children[0].children[0].name)
        }
    }

    // MARK: Regexp

    func testCustomGroupRegexp() throws {
        let class1 = SourceKittenDict.mkClass(name: "BClass")
        let class2 = SourceKittenDict.mkClass(name: "AClass")
        let class3 = SourceKittenDict.mkClass(name: "Classical")
        let file = SourceKittenDict.mkFile().with(children: [class1, class2, class3])

        let yaml = """
                   custom_groups:
                     - name: RegGroup
                       children:
                         - /Class$/
                         - /Flurb/
                   """

        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            print(system.group.groupCustom.groups)
            TestLogger.install()
            let items = try system.run(file.asGatherPasses)
            XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
            XCTAssertEqual(2, items.count)
            XCTAssertEqual("RegGroup", items[0].name)
            XCTAssertEqual(2, items[0].children.count)
            XCTAssertEqual("AClass", items[0].children[0].name)
            XCTAssertEqual("BClass", items[0].children[1].name)
            XCTAssertEqual("Types", items[1].name)
        }
    }

    func testCustomGroupModuleRegexp() throws {
        let class1 = SourceKittenDict.mkClass(name: "AClass")
        let class2 = SourceKittenDict.mkClass(name: "BClass")
        let class3 = SourceKittenDict.mkClass(name: "CClass")
        let pass1 = SourceKittenDict.mkFile()
            .with(children: [class1, class2])
            .asGatherDef()
            .asPass(moduleName: "CMod", pathName: "")
        let pass2 = SourceKittenDict.mkFile()
            .with(children: [class3])
            .asGatherDef()
            .asPass(moduleName: "BMod", pathName: "")

        let yaml = """
                   custom_groups:
                     - name: RegGroup
                       children:
                         - /^C.*/
                   """
        try withTempConfigFile(yaml: yaml) { url in
            let system = System(cliArgs: ["--config=\(url.path)"])
            let items = try system.run([pass1, pass2])
            XCTAssertEqual(1, items.count)
        }
    }

    func testCustomGroupBadRegexp() throws {
        let badRegexp = """
                        custom_groups:
                           - name: N
                             children:
                               - /Class(/
                        """
        checkCustomParseError(badRegexp, .errCfgRegexp)
    }

    // MARK: Guide titles

    func testGuideTitles() throws {
        let tmpDir = try TemporaryDirectory()
        let filename = "Guide.md"
        try "By guide".write(to: tmpDir.directoryURL.appendingPathComponent(filename))

        let yaml = """
                   guides: "\(tmpDir.directoryURL.path)/*"
                   guide_titles:
                     - name: Guide
                       title: The Guide
                     - name: Guide2
                       title: Missing Guide
                     - name: Guide
                       title: Duplicate Guide
                   """

        try withTempConfigFile(yaml: yaml) { url in
            TestLogger.install()
            let system = System(cliArgs: ["--config=\(url.path)"])
            let items = try system.run([])
            XCTAssertEqual(2, TestLogger.shared.diagsBuf.count)
            XCTAssertEqual(1, items.count)
            XCTAssertEqual("Guide", items[0].children[0].name)
            XCTAssertEqual("The Guide", items[0].children[0].titlePreferring(language: .swift).first!.value)
        }
    }

    func testBadGuideTitles() throws {
        let badTitle = """
                       guide_titles:
                          - name: N
                       """
        checkCustomParseError(badTitle, .errCfgGuideTitleFields)
    }

    // MARK: Group-by-Path

    struct FullerSystem {
        let config: Config
        let gather: Gather
        let merge: Merge
        let group: Group

        init(_ opts: [String]) throws {
            config = Config()
            gather = Gather(config: config)
            merge = Merge(config: config)
            group = Group(config: config)
            try config.processOptions(cliOpts: opts)
        }

        func run() throws -> [Item] {
            try group.group(merged: merge.merge(gathered: gather.gather()))
        }
    }

    func testGroupByPath() throws {
        let srcDirURL = fixturesURL.appendingPathComponent("GroupByPath")
        let guideURL = fixturesURL
            .appendingPathComponent("LayoutTest")
            .appendingPathComponent("guides")
            .appendingPathComponent("Guide.md")

        let system = try FullerSystem([
            "--min-acl=private",
            "--source-directory", srcDirURL.path,
            "--guides", guideURL.path,
            "--group-style", "path"
        ])

        let grouped = try system.run()
        XCTAssertEqual(3, grouped.count)
    }
}
