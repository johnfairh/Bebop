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
        try! config.processOptions(cliOpts: cliArgs)
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
        XCTAssertEqual("Types", groups[0].title["en"])
        XCTAssertEqual(2, groups[0].children.count)
        XCTAssertEqual("C1", groups[0].children[0].name)
        XCTAssertEqual("c1", groups[0].children[0].slug)
        XCTAssertEqual(ItemKind.variable.name, groups[1].slug)
        XCTAssertEqual(1, groups[1].children.count)
    }
}
