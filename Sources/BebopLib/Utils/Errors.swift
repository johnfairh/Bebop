//
//  Errors.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//
import Foundation

/// Type thrown by Bebop when there is a problem meaning execution must stop.
public struct BBError: CustomStringConvertible, CustomDebugStringConvertible, Error, LocalizedError {
    let key: L10n.Localizable
    let source: String
    public let message: String

    init(_ key: L10n.Localizable, _ args: Any ..., file: String = #filePath, line: Int = #line) {
        self.key = key
        self.source = "\(file) line \(line)"
        self.message = .localized(key, subs: args)
    }

    init(_ text: String, file: String = #filePath, line: Int = #line) {
        self.key = .errNotImplemented
        self.source = "\(file) line \(line)"
        self.message = text
    }

    public var description: String { message }
    public var debugDescription: String { "\(message) (\(source))" }
    public var errorDescription: String? { message }
}
