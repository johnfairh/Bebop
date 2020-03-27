//
//  TestFormat.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest

@testable import J2Lib

fileprivate struct System {
    let config: Config
    let gather: Gather
    let merge: Merge
    let group: Group
    let format: Format
    let sitegen: GenSite

    init(cliArgs: [String] = []) {
        config = Config()
        gather = Gather(config: config)
        merge = Merge(config: config)
        group = Group(config: config)
        format = Format(config: config)
        sitegen = GenSite(config: config)
        try! config.processOptions(cliOpts: cliArgs + ["--min-acl=private"])
    }

    func run(_ passes: [GatherModulePass]) throws -> [Item] {
        let merged = try merge.merge(gathered: passes)
        let grouped = try group.group(merged: merged)
        return try format.format(items: grouped)
    }
}

class TestFormat: XCTestCase {
    override func setUp() {
        initResources()
    }

    // Passthrough empty
    func testEmpty() throws {
        let system = System()
        XCTAssertEqual(1, try system.run([]).count) //readme
    }

    // MARK: URLs

    // % escaping
    func testURLEscaping() throws {
        let system = System()
        let clas = SourceKittenDict.mkClass(name: "Trés")
                .with(children: [.mkInstanceVar(name: "bientôt")])
        let file = SourceKittenDict.mkFile().with(children: [clas])
        let formatted = try system.run(file.asGatherPasses)

        let clasItem = formatted[0].children[0]
        XCTAssertEqual("trés", clasItem.slug)
        XCTAssertEqual("types/trés.html", clasItem.url.filepath(fileExtension: ".html"))
        XCTAssertEqual("types/tr%C3%A9s.html", clasItem.url.url(fileExtension: ".html"))
        let varItem = clasItem.children[0]
        XCTAssertEqual("types/tr%C3%A9s.html#bient%C3%B4t", varItem.url.url(fileExtension: ".html"))
    }

    // URL policy -- when to generate a page for a leaf def

    private var urlPolicyFile: SourceKittenDict {
        let nestedClass = SourceKittenDict.mkClass(name: "NestedChildren")
            .with(children: [.mkInstanceVar(name: "InstanceVar2")])
        let class1 = SourceKittenDict.mkClass(name: "Top1")
            .with(children: [.mkClass(name: "NestedNoChildren"),
                             .mkInstanceVar(name: "InstanceVar1"),
                             nestedClass])
        return SourceKittenDict.mkFile()
            .with(children: [class1])
    }

    private func checkURL(_ item: Item, _ asPage: Bool, _ urlPath: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(asPage, item.renderAsPage, file: file, line: line)
        XCTAssertEqual(urlPath, item.url.url(fileExtension: ".html"), file: file, line: line)
    }

    func testDefaultURLPolicy() throws {
        let system = System(cliArgs: ["--topic-style=source-order"])
        let formatted = try system.run(urlPolicyFile.asGatherPasses)

        XCTAssertTrue(formatted[0].renderAsPage)
        XCTAssertEqual("Top1", formatted[0].children[0].name)
        checkURL(formatted[0].children[0], true, "types/top1.html")
        XCTAssertEqual("types/top1.html", formatted[0].children[0].url.filepath(fileExtension: ".html"))
        XCTAssertEqual(3, formatted[0].children[0].children.count)
        checkURL(formatted[0].children[0].children[0], false, "types/top1.html#nestednochildren")
        checkURL(formatted[0].children[0].children[1], false, "types/top1.html#instancevar1")
        checkURL(formatted[0].children[0].children[2], true, "types/top1/nestedchildren.html")
        checkURL(formatted[0].children[0].children[2].children[0], false, "types/top1/nestedchildren.html#instancevar2")
    }

    // MARK: README

    func testReadmeDetection() throws {
        let tmpdir = try TemporaryDirectory()

        // Explicit
        let readmeURL = tmpdir.directoryURL.appendingPathComponent("RME")
        try "RR".write(to: readmeURL)
        let system = System(cliArgs: ["--readme", readmeURL.path])

        let readme = try system.format.createReadme()
        XCTAssertEqual(Markdown("RR"), readme.content.markdown["en"])

        // Guessed
        try FileManager.preservingCurrentDirectory {
            try ["README.md", "README.markdown",
                 "README.mdown", "README"].enumerated().forEach { (offs, name) in
                let readmeURL = tmpdir.directoryURL.appendingPathComponent(name)
                try "RR".write(to: readmeURL)
                let system = System()
                if offs % 2 == 0 {
                    FileManager.default.changeCurrentDirectoryPath(tmpdir.directoryURL.path)
                } else {
                    FileManager.default.changeCurrentDirectoryPath("/")
                    system.config.published.sourceDirectoryURL = tmpdir.directoryURL
                }
                let readme = try system.format.createReadme()
                XCTAssertEqual(Markdown("RR"), readme.content.markdown["en"])
                try FileManager.default.removeItem(at: readmeURL)
            }
        }
    }

    func testReadmeFabrication() throws {
        try TemporaryDirectory.withNew {
            let system = System()
            let readme = try system.format.createReadme()
            let md = readme.content.markdown["en"]!.md
            XCTAssertTrue(md.contains("# Module"), md)
        }

        try TemporaryDirectory.withNew {
            let system = System(cliArgs: ["--author=Barney"])
            let readme = try system.format.createReadme()
            let md = readme.content.markdown["en"]!.md
            XCTAssertTrue(md.contains("# Module"))
            XCTAssertTrue(md.contains("### Authors\n\nBarney"))
        }
    }

    // MARK: Autolink

    func testAutolinkNames() {
        ["+method", "- method", "-method:argname"].forEach { m in
            XCTAssertTrue(m.isObjCMethodName, m)
            XCTAssertFalse(m.isObjCClassMethodName, m)
        }

        XCTAssertFalse("+".isObjCMethodName)

        ["+[Class method:name]",
         "+ [Class (category) method:name]",
         "+ [Class(category) method:name]",
        ].forEach { m in
            XCTAssertTrue(m.isObjCClassMethodName, m)
            XCTAssertEqual("Class.+method:name", m.hierarchical, m)
        }

        let malformed = "+[Class incomplete"
        XCTAssertTrue(malformed.isObjCClassMethodName)
        XCTAssertEqual(malformed, malformed.hierarchical)
    }

    func testAutoLinkLookupSwift() throws {
        let swMethod = SourceKittenDict.mkMethod(name: "method(arg:)")
        let swField = SourceKittenDict.mkInstanceVar(name: "variable")
        let swClass = SourceKittenDict.mkClass(name: "SwiftClass").with(children: [swMethod, swField])

        let swFile = SourceKittenDict.mkFile().with(children: [swClass])
        let swPass = swFile.asGatherDef().asPass(moduleName: "SwModule")

        let system = System()
        let filtered = try system.run([swPass])
        XCTAssertEqual(2, filtered.count)

        var swClassDef: DefItem!
        ["SwiftClass", "SwModule.SwiftClass"].forEach { n in
            guard let (classDef, lang) = system.format.autolink.def(for: n, context: filtered[0]) else {
                XCTFail("Couldn't look up class")
                return
            }
            XCTAssertEqual(DefLanguage.swift, lang)
            XCTAssertEqual("SwiftClass", classDef.name)
            swClassDef = classDef
        }

        // relative failure
        let res = system.format.autolink.def(for: "variable", context: swClassDef)
        XCTAssertNil(res)
        guard let (varDef, _) = system.format.autolink.def(for: "SwiftClass.variable", context: swClassDef) else {
            XCTFail("Couldn't look up var")
            return
        }
        XCTAssertEqual("variable", varDef.name)

        // relative success
        guard let (meth1, _) = system.format.autolink.def(for: "method(arg:)", context: varDef) else {
            XCTFail("Couldn't look up method")
            return
        }
        XCTAssertEqual("method(arg:)", meth1.name)

        // abbreviated lookup
        guard let (meth2, _) = system.format.autolink.def(for: "SwiftClass.method(...)", context: filtered[0]) else {
            XCTFail("Couldn't look up abbreviated method")
            return
        }
        XCTAssertEqual("method(arg:)", meth2.name)
    }

    #if os(macOS)
    func testAutoLinkLookupObjC() throws {
        let oMethod = SourceKittenDict.mkObjCMethod(name: "-method:param:", swiftName: "method(param:)")
        let oProperty = SourceKittenDict.mkObjCProperty(name: "value", swiftName: "value")
        let oClass = SourceKittenDict.mkObjCClass(name: "OClass", swiftName: "SClass")
            .with(children: [oMethod, oProperty])
        let oClass2 = SourceKittenDict.mkObjCClass(name: "OClass").with(usr: "OClass2") // dup name

        let passes = SourceKittenDict.mkFile().with(children: [oClass, oClass2]).asGatherPasses
        let system = System()
        let filtered = try system.run(passes)
        XCTAssertEqual(2, filtered.count)

        guard let (classDef, lang) = system.format.autolink.def(for: "OClass", context: filtered[0]),
            lang == .objc,
            classDef.name == "OClass" else {
            XCTFail("Couldn't look up OClass")
            return
        }

        guard let (classDef2, lang2) = system.format.autolink.def(for: "SClass", context: filtered[0]),
            lang2 == .swift,
            classDef2.name == "OClass" else {
            XCTFail("Couldn't look up SClass")
            return
        }

        guard let (mDef, _) = system.format.autolink.def(for: "-[OClass method:param:]", context: filtered[0]),
            mDef.name == "-method:param:" else {
            XCTFail("Couldn't look up full method")
            return
        }
        XCTAssertEqual("-[OClass method:param:]", mDef.fullyQualifiedName(for: .objc))
        XCTAssertEqual("SClass.method(param:)", mDef.fullyQualifiedName(for: .swift))

        guard let (mDef2, _) = system.format.autolink.def(for: "SClass.method(...)", context: filtered[0]),
            mDef2.name == "-method:param:" else {
            XCTFail("Couldn't look up Swift method")
            return
        }

        guard let (mDef3, _) = system.format.autolink.def(for: "-method:param:", context: classDef),
            mDef3.name == "-method:param:" else {
            XCTFail("Couldn't look up nested name")
            return
        }

        if let (pDef2, _) = system.format.autolink.def(for: "value", context: classDef) {
            XCTFail("Managed to resolve relative name from wrong place: \(pDef2)")
            return
        }

        if let (mDef4, _) = system.format.autolink.def(for: "-badmethod", context: classDef) {
            XCTFail("Managed to resolve relative method from wrong place: \(mDef4)")
            return
        }

        guard let (pDef, _) = system.format.autolink.def(for: "value", context: mDef3),
            pDef.name == "value" else {
            XCTFail("Couldn't look up sibling name")
            return
        }
        XCTAssertEqual("OClass.value", pDef.fullyQualifiedName(for: .objc))
        XCTAssertEqual("SClass.value", pDef.fullyQualifiedName(for: .swift))
    }

    private func getLinkNames(html: String) -> [String] {
        html.re_matches("<code>(.*?)</code>").map { $0[1] }
    }

    func testAutolinkLinks() throws {
        let oMethod = SourceKittenDict.mkObjCMethod(name: "-method:param:", swiftName: "method(param:)")
        let oClass = SourceKittenDict.mkObjCClass(name: "OClass", swiftName: "SClass")
            .with(children: [oMethod])
        let swClass = SourceKittenDict.mkClass(name: "SwiftClass")
        let passes = SourceKittenDict.mkFile().with(children: [oClass, swClass]).asGatherPasses
        let system = System()
        let filtered = try system.run(passes)
        XCTAssertEqual(2, filtered.count)

        guard let link1 = system.format.autolink.link(for: "OClass", context: filtered[0]) else {
            XCTFail("Couldn't resolve OClass")
            return
        }
        XCTAssertEqual(["OClass", "SClass"], getLinkNames(html: link1.html))

        guard let link2 = system.format.autolink.link(for: "SwiftClass", context: filtered[0]) else {
            XCTFail("Couldn't resolve SwiftClass")
            return
        }
        XCTAssertEqual(["SwiftClass"], getLinkNames(html: link2.html))

        guard let (classDef, _) = system.format.autolink.def(for: "OClass", context: filtered[0]) else {
            XCTFail("Couldn't resolve OClass to def")
            return
        }
        guard let link3 = system.format.autolink.link(for: "-method:param:", context: classDef) else {
            XCTFail("Couldn't resolve child method link")
            return
        }
        XCTAssertEqual(["-method:param:", "method(param:)"], getLinkNames(html: link3.html))

        guard let link4 = system.format.autolink.link(for: "SClass.method(param:)", context: filtered[0]) else {
            XCTFail("Couldn't resolve method link")
            return
        }
        XCTAssertEqual(["SClass.method(param:)", "-[OClass method:param:]"], getLinkNames(html: link4.html))

        // errors
        if let link5 = system.format.autolink.link(for: "NotAThing", context: filtered[0]) {
            XCTFail("Managed result for NotAThing: \(link5)")
            return
        }

        if let link6 = system.format.autolink.link(for: "OClass", context: classDef) {
            XCTFail("Did self-link: \(link6)")
            return
        }
    }
    #endif

    func testHtmlHrefLifting() {
        let html = #"<a href="http://google.com/">"#
        XCTAssertEqual(html, html.htmlHrefLifted)

        let html2 = #"<a href="foop">"#
        XCTAssertEqual(html2, html2.htmlHrefLifted)

        let html3 = #"<a href="../foop">"#
        XCTAssertEqual(html2, html3.htmlHrefLifted)
    }

    // MARK: Custom abstract

    func testCustomAbstract() throws {
        TestLogger.uninstall()
        let swClass1 = SourceKittenDict.mkClass(name: "SwiftClass1")
        let swClass2 = SourceKittenDict.mkClass(name: "SwiftClass2").with(docs: "SwiftClass2 builtin")
        let passes = SourceKittenDict.mkFile().with(children: [swClass1, swClass2]).asGatherPasses

        let mdDir = try TemporaryDirectory()
        let guideURL = try mdDir.createFile(name: "Guide.md")
        try "I am the guide".write(to: guideURL)
        let class1AbstractURL = try mdDir.createFile(name: "SwiftClass1.md")
        try "SwiftClass1 CustomAbstract".write(to: class1AbstractURL)
        let class2AbstractURL = try mdDir.createFile(name: "SwiftClass2.md")
        try "SwiftClass2 CustomAbstract".write(to: class2AbstractURL)
        let typesAbstractURL = try mdDir.createFile(name: "Types.md")
        try "Types CustomAbstract".write(to: typesAbstractURL)

        let system = System(cliArgs: [
            "--guides=\(guideURL.path)",
            "--custom-abstracts=\(mdDir.directoryURL.appendingPathComponent("*.md").path)"
            ])

        let items = try system.run(passes)
        XCTAssertEqual(3, items.count)
        XCTAssertEqual("Types", items[1].name)
        XCTAssertTrue((items[1] as! GroupItem).customAbstract != nil)

        let class1Def = items[1].children[0] as! DefItem
        XCTAssertEqual("SwiftClass1", class1Def.name)
        XCTAssertEqual("SwiftClass1 CustomAbstract", class1Def.documentation.abstract!.plainText.get("en"))

        let class2Def = items[1].children[1] as! DefItem
        XCTAssertEqual("SwiftClass2", class2Def.name)
        XCTAssertEqual("SwiftClass2 CustomAbstract", class2Def.documentation.abstract!.plainText.get("en"))
        XCTAssertEqual("SwiftClass2 builtin", class2Def.documentation.discussion!.plainText.get("en"))

        // Overwrite
        let system2 = System(cliArgs: [
            "--guides=\(guideURL.path)",
            "--custom-abstracts=\(mdDir.directoryURL.appendingPathComponent("*.md").path)",
            "--custom-abstract-overwrite"
            ])
        let items2 = try system2.run(passes)

        let class2Def2 = items2[1].children[1] as! DefItem
        XCTAssertEqual("SwiftClass2", class2Def2.name)
        XCTAssertEqual("SwiftClass2 CustomAbstract", class2Def2.documentation.abstract!.plainText.get("en"))
        XCTAssertEqual("", class2Def2.documentation.discussion!.plainText.get("en"))

        // Markdown munging
        class2Def2.documentation.abstract = RichText("Orig Abstract")
        class2Def2.documentation.discussion = RichText("Orig Discussion")
        class2Def2.setCustomAbstract(markdown: .init(unlocalized: Markdown("- bullet")), overwrite: false)
        XCTAssertEqual("  - bullet\n\nOrig Abstract\n\nOrig Discussion", class2Def2.documentation.abstract!.plainText.get("en"))
        XCTAssertEqual("", class2Def2.documentation.discussion!.plainText.get("en"))
    }
}
