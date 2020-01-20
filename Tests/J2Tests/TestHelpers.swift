//
//  TestHelpers.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import J2Lib

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
func Do(code: () throws -> Void) {
    do {
        try code()
    } catch {
        XCTFail("Unexpected error thrown: \(error)")
    }
}
