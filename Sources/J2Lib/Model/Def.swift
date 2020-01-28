//
//  Def.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

public class Def: Encodable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public class DeclDef: Def {
    /// Module in which this definition is written
    public let moduleName: String

    /// For debug?  Which gather pass of the module this is from
    public let passIndex: Int

    public init?(moduleName: String, passIndex: Int, gatherDef: GatherDef) {
//        guard let name = gatherDef.sourceKittenDict[SwiftDocKey.name.rawValue] as? String else {
//            return nil
//        }
        self.moduleName = moduleName
        self.passIndex = passIndex
        super.init(name: "Mysterio")
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        try doEncode(to: encoder)
    }
}
