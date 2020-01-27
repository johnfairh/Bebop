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

/// Probably can delete this now...
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
    var messageBuf = [String]()
    var diagsBuf = [String]()
    var logger = Logger()
    var expectNothing = false
    var expectNoDiags = false
    var expectNoMessages = false

    init() {
        logger.logHandler = { m, d in
            XCTAssertFalse(self.expectNothing)
            if d {
                XCTAssertFalse(self.expectNoDiags)
                self.diagsBuf.append(m)
            } else {
                XCTAssertFalse(self.expectNoMessages)
                self.messageBuf.append(m)
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

extension XCTestCase {
    /// Set up so that the code can find the resources - needed for SPM
    /// where the built pieces are scattered.
    func prepareResourceBundle() {
        #if SWIFT_PACKAGE
        let bundlePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .path
        setenv(Resources.BUNDLE_ENV_VAR, strdup(bundlePath), 1)
        #endif
    }

    func initResources() {
        prepareResourceBundle()
        Resources.initialize()
    }

    var fixturesURL: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }
}
