//
//  TestLogger.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import J2Lib

fileprivate final class System {
    var messageBuf = ""
    var diagsBuf = ""
    var logger = Logger()

    init() {
        logger.logHandler = { m, d in
            if d {
                print(m, to: &self.diagsBuf)
            } else {
                print(m, to: &self.messageBuf)
            }
        }
    }
}

class TestLogger: XCTestCase {
    func testBasic() {
        let system = System()
        system.logger.log(.debug, "d") // swallowed
        system.logger.log(.info, "i")
        system.logger.log(.warning, "w")
        system.logger.log(.error, "e")
        XCTAssertEqual("i\n", system.messageBuf)
        XCTAssertEqual("w\ne\n", system.diagsBuf)
    }

    func testDiags() {
        let system = System()
        system.logger.activeLevels = Logger.allLevels
        system.logger.diagnosticLevels = Logger.allLevels
        system.logger.log(.debug, "d")
        system.logger.log(.info, "i")
        system.logger.log(.warning, "w")
        system.logger.log(.error, "e")
        XCTAssertEqual("", system.messageBuf)
        XCTAssertEqual("d\ni\nw\ne\n", system.diagsBuf)
    }

    func testPrefix() {
        let system = System()
        system.logger.messagePrefix = { level in "\(level): "}
        system.logger.log(.info, "test")
        XCTAssertEqual("info: test\n", system.messageBuf)
    }
}
