//
//  TestIdentifiers.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

class TestIdentifiers: XCTestCase {

    func testSlug() {
        XCTAssertEqual("aaa", "aaa".slugged)
        XCTAssertEqual("aaa", "aAa".slugged)
        XCTAssertEqual("aa-a", "aA a".slugged)
        XCTAssertEqual("beginners-guide", "Beginner's guide".slugged)
        XCTAssertEqual("名词说明", "名词说明".slugged)
        XCTAssertEqual("", "".slugged)
        XCTAssertEqual("😀", "😀".slugged)
        XCTAssertEqual("e", "!".slugged)
    }

    func testUnique() {
        let uniquer = StringUniquer()
        XCTAssertEqual("aaa", uniquer.unique("aaa"))
        XCTAssertEqual("aaa1", uniquer.unique("aaa"))
        XCTAssertEqual("aaa2", uniquer.unique("aaa"))
        XCTAssertEqual("bbb", uniquer.unique("bbb"))
    }

    // Sanity check that the built-in escapes work properly

    private func checkURLescaping(_ from: String, via: String, file: StaticString = #file, line: UInt = #line) {
        let escaped = from.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        XCTAssertEqual(via, escaped)
        let unescaped = escaped?.removingPercentEncoding
        XCTAssertEqual(from, unescaped)
    }

    func testURLescaping() {
        checkURLescaping("aaa", via: "aaa")
        checkURLescaping("a a", via: "a%20a")
        checkURLescaping("aa名aa", via: "aa%E5%90%8Daa")

        // be careful - slash is treated as a path separator not a path-element-character for encoding....
        checkURLescaping("a/a", via: "a/a") // not %2F
    }
}
