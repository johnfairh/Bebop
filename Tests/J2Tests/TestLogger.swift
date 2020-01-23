//
//  TestLogger.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import J2Lib

class TestLogging: XCTestCase {
    func testBasic() {
        let system = TestLogger()
        system.logger.log(.debug, "d") // swallowed
        system.logger.log(.info, "i")
        system.logger.log(.warning, "w")
        system.logger.log(.error, "e")
        XCTAssertEqual(["i"], system.messageBuf)
        XCTAssertEqual(["w", "e"], system.diagsBuf)
    }

    func testDiags() {
        let system = TestLogger()
        system.logger.activeLevels = Logger.allLevels
        system.logger.diagnosticLevels = Logger.allLevels
        system.logger.log(.debug, "d")
        system.logger.log(.info, "i")
        system.logger.log(.warning, "w")
        system.logger.log(.error, "e")
        XCTAssertEqual([], system.messageBuf)
        XCTAssertEqual(["d", "i", "w", "e"], system.diagsBuf)
    }

    func testPrefix() {
        let system = TestLogger()
        system.logger.messagePrefix = { level in "\(level): "}
        system.logger.log(.info, "test")
        XCTAssertEqual(["info: test"], system.messageBuf)
    }
}
