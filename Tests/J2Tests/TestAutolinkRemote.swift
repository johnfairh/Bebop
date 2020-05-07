//
//  TestAutolinkRemote.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

class TestAutolinkRemote: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testFetch() throws {
        let url = URL(string: "https://johnfairh.github.io/RubyGateway/badge.svg")!
        let data = try url.fetch()
        XCTAssertTrue(data.count > 500)

        let url2 = URL(string: "https://johnfairh.github.io/RubyGateway/bodge.svg")!
        AssertThrows(try url2.fetch(), .errUrlFetch)
    }
}
