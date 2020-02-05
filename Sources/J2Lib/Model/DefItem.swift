//
//  DefItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// Base class of definition items -- those that correspond to a definition in
/// some source code.
public class DefItem: Item {
    /// Module in which this definition is written
    public let moduleName: String
    /// For debug?  Which gather pass of the module this is from
    public let passIndex: Int
    /// Kind of the definition
    public let kind: DefKind
    /// Swift declaration
    public let swiftDeclaration: SwiftDeclaration
    /// Documentation
    public let documentation: Localized<DefMarkdownDocs>

    /// Create from a gathered definition
    public init?(moduleName: String, passIndex: Int, gatherDef: GatherDef) {
        guard let name = gatherDef.sourceKittenDict[SwiftDocKey.name.rawValue] as? String,
            let kind = gatherDef.kind else {
            // XXX wrn - lots to add here tho, leave for now
            logWarning("Incomplete def, ignoring -- missing name")
            return nil
        }
        let children = gatherDef.children.compactMap {
            DefItem(moduleName: moduleName, passIndex: passIndex, gatherDef: $0)
        }
        self.moduleName = moduleName
        self.passIndex = passIndex
        self.kind = kind

        if let swiftDeclInfo = gatherDef.swiftDeclaration {
            swiftDeclaration = swiftDeclInfo
        } else {
            swiftDeclaration = SwiftDeclaration()
            if kind.isSwift {
                // XXX wrn
                logWarning("No declaration, ignoring")
                return nil
            }
        }
        documentation = gatherDef.translatedDocs

        super.init(name: name, children: children)
    }

    /// Used to create the `decls-json` product.
    public override func encode(to encoder: Encoder) throws {
        try doEncode(to: encoder)
    }
}
