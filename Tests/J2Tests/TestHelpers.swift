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

extension J2Lib.Error {
    func sameCategory(other: Error) -> Bool {
        if case .options(_) = self, case .options(_) = other { return true }
        if case .notImplemented(_) = self, case .notImplemented(_) = other { return true }
        return false
    }
}

/// `XCTAssertNoThrow` is ugly, `throws` on the method loses the error details, so ...
func Do(code: () throws -> Void) {
    do {
        try code()
    } catch {
        XCTFail("Unexpected error thrown: \(error)")
    }
}
