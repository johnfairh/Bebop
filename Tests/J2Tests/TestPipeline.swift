//
//  TestPipeline.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

class TestPipeline: XCTestCase {
    func testResourceSetup() {
        #if SWIFT_PACKAGE
        Resources.injectedMainBundleUrl = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
        #endif
        Resources.initialize()
    }
}
