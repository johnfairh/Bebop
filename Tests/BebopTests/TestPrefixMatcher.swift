//
//  TestPrefixMatcher.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

class TestPrefixMatcher: XCTestCase {

    func testLeaf() {
        var matcher = PrefixMatcher()
        matcher.insert("boo")

        XCTAssertEqual("boo", matcher.match("b"))
        XCTAssertEqual("boo", matcher.match("bo"))
        XCTAssertEqual("boo", matcher.match("boo"))
        XCTAssertNil(matcher.match("boom"))
    }

    func testNode() {
        var matcher = PrefixMatcher()
        matcher.insert("foo")
        matcher.insert("bar")
        
        XCTAssertEqual("foo", matcher.match("f"))
        XCTAssertEqual("foo", matcher.match("fo"))
        XCTAssertEqual("foo", matcher.match("foo"))
        XCTAssertNil(matcher.match("foa"))
        XCTAssertNil(matcher.match("foom"))

        XCTAssertEqual("bar", matcher.match("b"))
        XCTAssertEqual("bar", matcher.match("ba"))
        XCTAssertEqual("bar", matcher.match("bar"))
    }

    func testDuplicate() {
        var matcher = PrefixMatcher()
        matcher.insert("foo")
        matcher.insert("foo")
        XCTAssertEqual("foo", matcher.match("foo"))

        matcher.insert("fob")
        matcher.insert("fo")
        matcher.insert("foo")
        matcher.insert("foom")
        matcher.insert("foop")
        matcher.insert("foo")

        XCTAssertNil(matcher.match("fo")) // ambiguous self-prefix
        XCTAssertNil(matcher.match("foo")) // ambiguous self-prefix

        XCTAssertEqual("foom", matcher.match("foom"))
        XCTAssertEqual("foop", matcher.match("foop"))
        XCTAssertEqual(nil, matcher.match("foopm"))
        XCTAssertEqual(nil, matcher.match("fb"))
    }

    func testReal() {
        var matcher = PrefixMatcher()
        matcher.insert("coverage")
        matcher.insert("profiling")
        matcher.insert("prolix")

        XCTAssertEqual("coverage", matcher.match("cov"))
        XCTAssertEqual("profiling", matcher.match("prof"))
        XCTAssertNil(matcher.match("pro"))
        XCTAssertEqual("prolix", matcher.match("prolix"))
        XCTAssertNil(matcher.match("prolapse"))
        XCTAssertNil(matcher.match("zen"))
    }

    func testCorner() {
        var matcher = PrefixMatcher()
        matcher.insert("")
        XCTAssertNil(matcher.match(""))
    }
}
