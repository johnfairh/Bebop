//
//  Def.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// The base class of things that appear in the documentation tree.
///
/// Encodable support is for creating the `decls-json` product post-Merge.
public class Item: Encodable {
    /// The name of the item in its scope
    public let name: String
    /// Children in the documentation tree
    public let children: [Item]

    public init(name: String, children: [Item]) {
        self.name = name
        self.children = children
    }
}

/// Base class of definition items -- those that correspond to a definition in
/// some source code.
public class DefItem: Item {
    /// Module in which this definition is written
    public let moduleName: String

    /// For debug?  Which gather pass of the module this is from
    public let passIndex: Int

    /// Create from a gathered definition
    public init?(moduleName: String, passIndex: Int, gatherDef: GatherDef) {
        guard let name = gatherDef.sourceKittenDict[SwiftDocKey.name.rawValue] as? String else {
            // XXX wrn
            return nil
        }
        let children = gatherDef.children.compactMap {
            DefItem(moduleName: moduleName, passIndex: passIndex, gatherDef: $0)
        }
        self.moduleName = moduleName
        self.passIndex = passIndex
        super.init(name: name, children: children)
    }

    /// Used to create the `decls-json` product.
    public override func encode(to encoder: Encoder) throws {
        try doEncode(to: encoder)
    }
}
