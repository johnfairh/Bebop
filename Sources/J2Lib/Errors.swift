//
//  Errors.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public enum Error: CustomStringConvertible, CustomDebugStringConvertible, Swift.Error {
    case options(String)
    case notImplemented(String)

    public var description: String {
        switch self {
        case .options(let message): return message
        case .notImplemented(let feature): return "Not implemented: \(feature)"
        }
    }

    public var debugDescription: String {
        switch self {
        case .options(let message): return "[options parsing] \(message)"
        case .notImplemented: return description
        }
    }

    /// For unit testing.  Not too convinced.
    public func sameCategory(other: Error) -> Bool {
        if case .options(_) = self, case .options(_) = other { return true }
        if case .notImplemented(_) = self, case .notImplemented(_) = other { return true }
        return false
    }
}