//
//  DefJSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

extension Def {
    enum CodingKeys: String, CodingKey {
        case name = "key.j2.name"
    }
}

fileprivate enum DeclDefCodingKeys: String, CodingKey {
    case moduleName = "key.j2.module_name"
    case passIndex = "key.j2.pass_index"
}

extension DeclDef {
    func doEncode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DeclDefCodingKeys.self)
        try container.encode(self.moduleName, forKey: .moduleName)
        try container.encode(self.passIndex, forKey: .passIndex)
    }
}

extension Array where Element == DeclDef {
    public func toJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
