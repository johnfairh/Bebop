//
//  Errors.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

/// Type thrown by J2 when there is a problem meaning execution must stop.
public class Error: CustomStringConvertible, CustomDebugStringConvertible, Swift.Error, LocalizedError {
    public let file: String
    public let line: Int

    public var errorSource: String {
        "\(file) line \(line)"
    }

    fileprivate init(file: String, line: Int) {
        self.file = file
        self.line = line
    }

    public var description: String { "" }
    public var debugDescription: String { "" }
    public var errorDescription: String? { description }
}

/// A problem with parsing options.
public final class OptionsError: Error {
    public let message: String

    public init(_ message: String = "", file: String = #file, line: Int = #line) {
        self.message = message
        super.init(file: file, line: line)
    }

    public override var description: String {
        message
    }

    public override var debugDescription: String {
        "[options parsing] \(description) (\(errorSource))"
    }
}

/// A problem with data gathering
public final class GatherError: Error {
    public let message: String

    public init(_ message: String = "", file: String = #file, line: Int = #line) {
        self.message = message
        super.init(file: file, line: line)
    }

    public override var description: String {
        message
    }

    public override var debugDescription: String {
        "[gather] \(description) (\(errorSource))"
    }
}

/// Some reachable code isn't implemented
public final class NotImplementedError: Error {
    public let function: String

    public init(_ function: String = "", file: String = #file, line: Int = #line) {
        self.function = function
        super.init(file: file, line: line)
    }

    public override var description: String {
        "Not implemented: \(function)"
    }

    public override var debugDescription: String {
        "\(description) (\(errorSource))]"
    }
}
