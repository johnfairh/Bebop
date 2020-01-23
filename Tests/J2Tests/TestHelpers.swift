//
//  TestHelpers.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

/// Execute some code and check it throws a particular category of error.
/// 
/// - Parameters:
///   - expression: code to run
///   - expectedError: expected `J2Lib.Error` to be thrown - uses `J2Lib.Error.sameCategory(other:)`
///                    to compare, meaning text payload is not compared - just the enum case.
public func AssertThrows<Err, Ret>(_ expression: @autoclosure () throws -> Ret,
                                   _ expectedError: Err.Type,
                                   _ message: String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line) where Err: CustomDebugStringConvertible {
    XCTAssertThrowsError(try expression(), message, file: file, line: line, { actualError in
        guard let j2Error = actualError as? Err else {
            XCTFail("\(actualError) is not \(expectedError)", file: file, line: line)
            return
        }
        print(j2Error.debugDescription)
    })
}

/// `XCTAssertNoThrow` is ugly, `throws` on the method loses the error details, so ...
/// (that would be because you haven't understood the localizedErrorDescription thing....)
func Do(code: () throws -> Void) {
    do {
        try code()
    } catch {
        XCTFail("Unexpected error thrown: \(error)")
    }
}

// Logger drop-in to log to string buffers
//
final class TestLogger {
    var messageBuf = ""
    var diagsBuf = ""
    var logger = Logger()
    var expectNothing = false

    init() {
        logger.logHandler = { m, d in
            XCTAssertFalse(self.expectNothing)
            if d {
                print(m, to: &self.diagsBuf)
            } else {
                print(m, to: &self.messageBuf)
            }
        }
    }

    static var shared = TestLogger()

    static func install() {
        let testLogger = TestLogger()
        shared = testLogger
        Logger.shared = testLogger.logger
    }

    static func uninstall() {
        Logger.shared = Logger()
    }
}
