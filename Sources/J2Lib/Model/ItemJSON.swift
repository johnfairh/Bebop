//
//  DefJSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Bits to do with creating the decl-json product

fileprivate enum DefItemCodingKeys: String, CodingKey {
    case moduleName
    case passIndex
}

extension DefItem {
    func doEncode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: DefItemCodingKeys.self)
        try container.encode(self.moduleName, forKey: .moduleName)
        try container.encode(self.passIndex, forKey: .passIndex)
    }
}

extension Array where Element == DefItem {
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        let json = String(data: data, encoding: .utf8)!
        // Get rid of empty arrays....
        return json.re_sub(#"\n +"\w+" : \[\n\n +\],"#, with: "")
    }
}
