//
//  Version.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//
import Foundation

public enum Version {
    private static let actualBebopLibVersion = "1.4.0"

    /// Wrapper for test harness
    public static var bebopLibVersion: String {
        guard ProcessInfo.processInfo.environment["BEBOP_STATIC_VERSION"] == nil else {
            return "1.0"
        }
        return actualBebopLibVersion
    }

    static func canImport(from: String) -> Bool {
        from <= bebopLibVersion
        // XXX this is not right!
    }
}
