//
//  DefJSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Bits to do with creating the decl-json product

extension DefItem {
    private enum CodingKeys: CodingKey {
        case moduleName
        case passIndex
        case kind
        case swiftDeclaration
        case documentation
    }

    // I may well have got this wrong, but I am using classes here - can't see
    // how to use the auto-gen encode code for the derived class fields.
    final func doEncode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(moduleName, forKey: .moduleName)
        try container.encode(passIndex, forKey: .passIndex)
        try container.encode(defKind.key, forKey: .kind)
        if !swiftDeclaration.declaration.isEmpty {
            try container.encode(swiftDeclaration, forKey: .swiftDeclaration)
        }
        if !documentation.isEmpty {
            try container.encode(documentation, forKey: .documentation)
        }
    }
}

extension Array where Element == DefItem {
    public func toJSON() throws -> String {
        try JSON.encode(self)
    }
}
