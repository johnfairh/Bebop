//
//  Errors.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

/// Type thrown by J2 when there is a problem meaning execution must stop.
public struct J2Error: CustomStringConvertible, CustomDebugStringConvertible, Error, LocalizedError {
    let key: L10n.Localizable
    public let message: String

    init(_ key: L10n.Localizable, _ args: Any ..., file: String = #file, line: Int = #line) {
        self.key = key
        self.message = .localized(key, args) + " (\(file) line \(line)"
    }

    init(_ text: String, file: String = #file, line: Int = #line) {
        self.key = .errNotImplemented
        self.message = text + " (\(file) line \(line)"
    }

    public var description: String { message }
    public var debugDescription: String { message }
    public var errorDescription: String? { message }
}
