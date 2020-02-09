//
//  JSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// namespace
public enum JSON {
    /// Render an `Encodable` type as JSON using preferred formatting options.
    public static func encode<T: Encodable>(_ t: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(t)
        let json = String(data: data, encoding: .utf8)!
        // Improve formatting of empty arrays / hashes
        return json.re_sub(#"(?<=[\[{])\s*(?=[\]}])"#, with: "")
        // (and omg, another open-source foundation difference appears,
        //  trailing spaces galore on linux...)
    }
}
