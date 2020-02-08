//
//  TestIdentifiers.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import J2Lib

class TestIdentifiers: XCTestCase {

    func testSlug() {
        XCTAssertEqual("aaa", "aaa".slugged)
        XCTAssertEqual("aaa", "aAa".slugged)
        XCTAssertEqual("aa-a", "aA a".slugged)
        XCTAssertEqual("beginners-guide", "Beginner's guide".slugged)
        XCTAssertEqual("名词说明", "名词说明".slugged)
    }

    func testUnique() {
        var uniquer = StringUniquer()
        XCTAssertEqual("aaa", uniquer.unique("aaa"))
        XCTAssertEqual("aaa1", uniquer.unique("aaa"))
        XCTAssertEqual("aaa2", uniquer.unique("aaa"))
        XCTAssertEqual("bbb", uniquer.unique("bbb"))
    }
}
