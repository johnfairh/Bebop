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
public func AssertThrows<T>(_ expression: @autoclosure () throws -> T,
                            _ expectedError: Error,
                            _ message: String = "",
                            file: StaticString = #file,
                            line: UInt = #line) {
    XCTAssertThrowsError(try expression(), message, file: file, line: line, { actualError in
        guard let j2Error = actualError as? Error else {
            XCTFail("\(actualError) is not Error", file: file, line: line)
            return
        }
        XCTAssertTrue(j2Error.sameCategory(other: expectedError), file: file, line: line)
        print(j2Error.debugDescription)
    })
}
