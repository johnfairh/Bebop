//
//  TestGlob.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

class TestGlob: XCTestCase {

    func testFnMatch() {
        XCTAssertTrue (Glob.match("/a/b/c", path: "/a/b/c"))
        XCTAssertFalse(Glob.match("/a/b/d", path: "/a/b/c"))
        XCTAssertTrue (Glob.match("/a/?/c", path: "/a/b/c"))
        XCTAssertTrue (Glob.match("/a/?/c", path: "/a/b/c"))
        XCTAssertTrue (Glob.match("/a/*/c", path: "/a/b/c"))
        XCTAssertTrue (Glob.match("/*c",    path: "/a/b/c"))
        XCTAssertFalse(Glob.match("/*d",    path: "/a/b/c"))
        XCTAssertTrue (Glob.match("*",      path: "/a/b/c"))
        XCTAssertTrue (Glob.match("*",      path: ""))
        XCTAssertFalse(Glob.match("/a/*",   path: ""))
    }

    func testFnMatchEscapes() {
        XCTAssertFalse(Glob.match(#"/a/\?/c"#, path: "/a/b/c"))
        XCTAssertTrue (Glob.match(#"/a/\?/c"#, path: "/a/?/c"))
        XCTAssertFalse(Glob.match(#"/a/\*/c"#, path: "/a/b/c"))
        XCTAssertTrue (Glob.match(#"/a/\*/c"#, path: "/a/*/c"))
    }

    func testFilesGlob() {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packFiles = projectRoot.filesMatching("Pack*")

        let expected = ["Package.resolved", "Package.swift"] // alphabetical order
            .map { projectRoot.path + "/\($0)" }

        XCTAssertEqual(expected, packFiles.map { $0.path })

        let noFiles = projectRoot.filesMatching("xxxxxx")
        XCTAssertTrue(noFiles.isEmpty)
    }
}
