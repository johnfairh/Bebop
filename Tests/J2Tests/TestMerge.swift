//
//  TestMerge.swift
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
    init() {
        config = Config()
        merge = Merge(config: config)
    }
}

class TestMerge: XCTestCase {
    override func setUp() {
        initResources()
    }

    // Utils for building interesting defs

    let goodRootDict = [ "key.diagnostic_stage" : "parse" ]
    let badRootDict = SourceKittenDict()

    func makeDefDict(name: String) -> SourceKittenDict {
        [ "key.name" : name ]
    }

    let badDefDict = SourceKittenDict()

    func add(child: SourceKittenDict, to parent: SourceKittenDict) -> SourceKittenDict {
        var parent = parent
        let newChildren: [SourceKittenDict]
        if let children = parent["key.substructure"] as? [SourceKittenDict] {
            newChildren = children + [child]
        } else {
            newChildren = [child]
        }
        parent["key.substructure"] = newChildren
        return parent
    }

    func makePasses(from def: GatherDef, moduleName: String, pathName: String) -> [GatherModulePass] {
        [GatherModulePass(moduleName: moduleName,
                          passIndex: 0,
                          files: [(pathName, def)])]
    }

    /// Normal file with one def
    func testGoodMergeImport() throws {
        let goodFile = add(child: makeDefDict(name: "Good"), to: goodRootDict)
        let goodDef = GatherDef(sourceKittenDict: goodFile, file: nil)
        let passes = makePasses(from: goodDef, moduleName: "GoodModule", pathName: "pathname")
        let system = System()
        TestLogger.install()
        TestLogger.shared.expectNothing = true
        let defItems = try system.merge.merge(gathered: passes)
        XCTAssertEqual(1, defItems.count)
        XCTAssertEqual("Good", defItems[0].name)
        XCTAssertEqual("GoodModule", defItems[0].moduleName)
    }

    /// Bad file
    func testBadFileMergeImport() throws {
        let badFile = badRootDict
        let badDef = GatherDef(sourceKittenDict: badFile, file: nil)
        let passes = makePasses(from: badDef, moduleName: "BadModule", pathName: "pathname")
        let system = System()
        TestLogger.install()
        let defItems = try system.merge.merge(gathered: passes)
        XCTAssertEqual(0, defItems.count)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    /// Normal file, one def with one bad child and one good
    func testBadDeclMergeImport() throws {
        let file = add(child: add(child: badDefDict,
                                  to: add(child: makeDefDict(name: "Good"),
                                          to: makeDefDict(name: "Parent"))),
                       to: goodRootDict)
        let def = GatherDef(sourceKittenDict: file, file: nil)
        let passes = makePasses(from: def, moduleName: "BadModule", pathName: "pathname")
        let system = System()
        TestLogger.install()
        let defItems = try system.merge.merge(gathered: passes)
        XCTAssertEqual(1, defItems.count)
        XCTAssertEqual("Parent", defItems[0].name)
        XCTAssertEqual(1, defItems[0].children.count)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    /// Decls json matches
    func testDeclsJson() throws {
        let pipeline = Pipeline()
        let spmTestURL = fixturesURL.appendingPathComponent("SpmSwiftModule")
        TestLogger.install()
        try pipeline.run(argv: ["--source-directory", spmTestURL.path,
                                "--products", "decls-json"])
        XCTAssertEqual(1, TestLogger.shared.outputBuf.count)

        let spmTestDeclsJsonURL = fixturesURL.appendingPathComponent("SpmSwiftModule.decls.json")

        let actualJson = TestLogger.shared.outputBuf[0]

        // to fix up when it changes...
        // try actualJson.write(to: spmTestDeclsJsonURL, atomically: true, encoding: .utf8)

        let expectedJson = try String(contentsOf: spmTestDeclsJsonURL)
        XCTAssertEqual(expectedJson, actualJson)
    }
}
