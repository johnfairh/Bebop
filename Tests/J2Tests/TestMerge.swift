//
//  TestMerge.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import SourceKittenFramework
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

    /// Normal file with one def
    func testGoodMergeImport() throws {
        let goodFile = SourceKittenDict.mkFile().with(children: [.mkClass(name: "Good", docs: "")])
        let system = System()
        TestLogger.install()
        TestLogger.shared.expectNothing = true
        let defItems = try system.merge.merge(gathered: goodFile.asGatherPasses)
        XCTAssertEqual(1, defItems.count)
        XCTAssertEqual("Good", defItems[0].name)
        XCTAssertEqual("module", defItems[0].location.moduleName)
    }

    /// Bad file
    func testBadFileMergeImport() throws {
        let badFile = SourceKittenDict()
        let system = System()
        TestLogger.install()
        let defItems = try system.merge.merge(gathered: badFile.asGatherPasses)
        XCTAssertEqual(0, defItems.count)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    /// Normal file, one def with one bad child and one good
    func testBadDeclMergeImport() throws {
        let clazz = SourceKittenDict.mkClass(name: "Parent").with(children: [
            .mkClass(name: "Good"),
            SourceKittenDict().with(usr: "usr") // bad
        ])
        let file = SourceKittenDict.mkFile().with(children: [clazz])
        let system = System()
        TestLogger.install()
        let defItems = try system.merge.merge(gathered: file.asGatherPasses)
        XCTAssertEqual(1, defItems.count)
        XCTAssertEqual("Parent", defItems[0].name)
        XCTAssertEqual(1, defItems[0].children.count)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    /// Bad-usr scenarios 1
    func testMissingUsrScenarios1() throws {
        TestLogger.install()
        let clazz = SourceKittenDict.mkClass(name: "C").without(field: .usr)
        let file = SourceKittenDict.mkFile().with(children: [clazz])
        let system = System()
        let defItems = try system.merge.merge(gathered: file.asGatherPasses)
        XCTAssertTrue(defItems.isEmpty)
        XCTAssertTrue(TestLogger.shared.diagsBuf.isEmpty)
    }

    /// Bad-usr scenarios 2
    func testMissingUsrScenarios2() throws {
        TestLogger.install()
        let clazz = SourceKittenDict.mkClass(name: "C")
            .without(field: .usr)
            .with(typename: "<<error-type>> -> String")
        let file = SourceKittenDict.mkFile().with(children: [clazz])
        let system = System()
        let defItems = try system.merge.merge(gathered: file.asGatherPasses)
        XCTAssertTrue(defItems.isEmpty)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    // Available
    func testMergeAvailable() throws {
        let macClass = SourceKittenDict.mkClass(name: "Clazz").asGatherDef(availability: "macOS")
        let linuxClass = SourceKittenDict.mkClass(name: "Clazz").asGatherDef(availability: "Linux")
        let file = GatherDef.mkFile(children: [macClass, linuxClass])
        let system = System()
        let defItems = try system.merge.merge(gathered: file.asPasses())
        XCTAssertEqual(1, defItems.count)
        XCTAssertEqual(["macOS", "Linux"], defItems[0].swiftDeclaration?.availability)
    }

    // Marks

    private func checkMark(_ dict: SourceKittenDict, _ markText: String, line: UInt = #line) {
        guard let mark = dict.asGatherDef().asTopicMark else {
            XCTFail("not a mark", line: line)
            return
        }
        XCTAssertEqual(Markdown(markText), mark.title.markdown["en"], line: line)
    }

    private func checkNotMark(_ dict: SourceKittenDict, line: UInt = #line) {
        if let mark = dict.asGatherDef().asTopicMark {
            XCTFail("not a mark: \(mark)")
        }
    }

    func testMarks() throws {
        checkMark(SourceKittenDict.mkSwiftMark(text: "MARK: mark"), "mark")
        checkMark(SourceKittenDict.mkSwiftMark(text: "MARK: mark -"), "mark")
        checkMark(SourceKittenDict.mkSwiftMark(text: "MARK: - mark"), "mark")
        checkMark(SourceKittenDict.mkSwiftMark(text: "MARK: - mark -"), "mark")
        #if os(macOS)
        checkMark(SourceKittenDict.mkObjCMark(text: "- mark"), "mark")
        #endif
        checkNotMark(SourceKittenDict.mkSwiftMark(text: "FIXME: fixme"))
    }
}
