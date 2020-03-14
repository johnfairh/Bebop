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
        let system = System()
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

    // README

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

    // Autolink

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
}
