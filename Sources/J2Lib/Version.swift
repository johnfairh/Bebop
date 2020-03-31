//
//  Version.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

public enum Version {
    public static let j2libVersion = "0.1"

    static func canImport(from: String) -> Bool {
        from <= j2libVersion
    }
}
