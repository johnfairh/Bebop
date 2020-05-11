//
//  Version.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

public enum Version {
    public static let bebopLibVersion = "1.0"

    static func canImport(from: String) -> Bool {
        from <= bebopLibVersion
    }
}
