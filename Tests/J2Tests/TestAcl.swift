//
//  TestAcl.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import SourceKittenFramework
@testable import J2Lib

class TestAcl: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testComparison() {
        let list: [DefAcl] = [.open, .public, .internal, .fileprivate, .private]
        list.enumerated().forEach { idx, acl in
            let includedBy = DefAcl.includedBy(acl: acl)
            let excludedBy = DefAcl.excludedBy(acl: acl)
            for incl in list[0..<idx] {
                XCTAssertTrue(acl < incl)
                XCTAssertNotNil(includedBy.firstIndex(of: incl))
                XCTAssertNil(excludedBy.firstIndex(of: incl))
            }
            for incl in list[(idx + 1)...] {
                XCTAssertTrue(acl >= incl)
                XCTAssertNotNil(excludedBy.firstIndex(of: incl))
                XCTAssertNil(includedBy.firstIndex(of: incl))
            }
        }
    }

    func testObjC() {
        let objCAcl = DefAcl.forObjC
        DefAcl.allCases.forEach { XCTAssertTrue($0 <= objCAcl) }
    }

    func testSourceKit() {
        let missing = SourceKittenDict.mkStruct(name: "Struct")
        let missingAcl = DefAcl(name: "Struct", dict: missing)
        XCTAssertEqual(DefAcl.internal, missingAcl)

        DefAcl.allCases.forEach { acl in
            let obj = SourceKittenDict
                .mkClass(name: "Cl")
                .with(accessibility: acl)
            let calcAcl = DefAcl(name: "Cl", dict: obj)
            XCTAssertEqual(acl, calcAcl)
        }

        let weird = SourceKittenDict
            .mkClass(name: "Cl")
            .with(field: "key.accessibility", value: "weird")
        XCTAssertEqual(DefAcl.internal, DefAcl(name: "Cl", dict: weird))

        let deinitMethod = SourceKittenDict
            .mkMethod(name: "deinit")
            .with(accessibility: .public)
        let calcDeinitAcl = DefAcl(name: "deinit", dict: deinitMethod)
        XCTAssertEqual(DefAcl.internal, calcDeinitAcl)
    }
}

