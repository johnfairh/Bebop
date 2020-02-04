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
    case kind
    case swiftDeclaration
    case documentation
}

extension DefItem {
    // I may well have got this wrong, but I am using classes here - can't see
    // how to use the auto-gen encode code for the derived class fields.
    func doEncode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: DefItemCodingKeys.self)
        try container.encode(moduleName, forKey: .moduleName)
        try container.encode(passIndex, forKey: .passIndex)
        try container.encode(kind.key, forKey: .kind)
        if !swiftDeclaration.declaration.isEmpty {
            try container.encode(swiftDeclaration, forKey: .swiftDeclaration)
        }
        if let documentation = documentation {
            try container.encode(documentation, forKey: .documentation)
        }
    }
}

extension Array where Element == DefItem {
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        let json = String(data: data, encoding: .utf8)!
        // Get rid of empty arrays...
        // (and omg, another open-source foundation difference appears,
        //  trailing spaces galore on linux...)
        return json.re_sub(#"\n +"\w+" : \[\n *\n +\],"#, with: "")
                .re_sub(#",\n +"\w+" : \[\n *\n +\](?=\n)"#, with: "")
    }
}
