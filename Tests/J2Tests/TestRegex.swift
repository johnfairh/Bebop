//
//  TestRegex.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

class TestRegex: XCTestCase {
    func testSplitNone() {
        let str = "123"
        XCTAssertEqual(["123"], str.re_split(","))

        let str2 = ""
        XCTAssertEqual([], str2.re_split(","))
    }

    func testSplit() {
        let str = "1,2,3"
        XCTAssertEqual(["1", "2", "3"], str.re_split(","))
    }

    func testSplitEnds() {
        let str = "1,2,"
        XCTAssertEqual(["1", "2"], str.re_split(","))

        let str2 = ",1,2"
        XCTAssertEqual(["1", "2"], str2.re_split(","))

        let str3 = ",1,2,"
        XCTAssertEqual(["1", "2"], str3.re_split(","))
    }

    func testSplitEmpty() {
        let str = "foo,,bar"
        XCTAssertEqual(["foo", "bar"], str.re_split(","))

        let str2 = ",,"
        XCTAssertEqual([], str2.re_split(","))
    }

    func testSplitOptions() {
        let str = "foobarFOObar"
        XCTAssertEqual(["barFOObar"], str.re_split("foo"))
        XCTAssertEqual(["bar", "bar"], str.re_split("foo", options: .i))
    }

    func testSub() {
        let str = "foofoo"
        XCTAssertEqual(str, str.re_sub("boo", with: "baa"))
        XCTAssertEqual("booboo", str.re_sub("f", with: "b"))
        XCTAssertEqual("foofoofoofoo", str.re_sub("foo", with: "$0$0"))
    }

    func testIsMatch() {
        let str = "cookie"
        XCTAssertTrue(str.re_isMatch("ook"))
        XCTAssertTrue(str.re_isMatch("ook"))
        XCTAssertTrue(str.re_isMatch("ie$"))
        XCTAssertTrue(!str.re_isMatch("COOK"))
        XCTAssertTrue(str.re_isMatch("COOK", options: .i))
    }

    func testMatchGroups() {
        let str = "Fish or beef"
        guard let matches = str.re_match(#"(.sh)(?: )(?<join>\w\w)\s"#) else {
            XCTFail("No match")
            return
        }
        XCTAssertEqual("ish or ", matches[0])
        XCTAssertEqual("or", matches["join"])
    }

    func testCheck() {
        initResources()
        AssertThrows(try "a(".re_check(), OptionsError.self)
    }
}
