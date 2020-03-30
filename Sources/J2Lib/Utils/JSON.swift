//
//  JSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// namespace
enum JSON {
    /// Render an `Encodable` type as JSON using preferred formatting options.
    static func encode<T: Encodable>(_ t: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(t)
        return from(data: data)
    }

    /// Render a Foundation "JSON object" using preferred formatting options.
    static func encode(data: Any) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
        return from(data: jsonData)
    }

    private static func from(data: Data) -> String {
        let json = String(data: data, encoding: .utf8)!
        // Improve formatting of empty arrays / hashes
        return json.re_sub(#"(?<=[\[{])\s*(?=[\]}])"#, with: "")
        // (and omg, another open-source foundation difference appears,
        //  trailing spaces galore on linux...)
    }

    /// Decode JSON to expected format
    static func decode<T>(_ json: String, _ type: T.Type) throws -> T {
        let object = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!)
        guard let result = object as? T else {
            throw OptionsError(.localized(.errJsonDecode, T.self, json))
        }
        return result
    }
}
