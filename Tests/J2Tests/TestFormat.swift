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
    let merge: Merge
    let group: Group
    let format: Format

    init(cliArgs: [String] = []) {
        config = Config()
        merge = Merge(config: config)
        group = Group(config: config)
        format = Format(config: config)
        try! config.processOptions(cliOpts: cliArgs)
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
        XCTAssertTrue(try system.run([]).isEmpty)
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

}