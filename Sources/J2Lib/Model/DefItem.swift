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
    public let defKind: DefKind
    /// Swift declaration
    public let swiftDeclaration: SwiftDeclaration // optional?
    /// Documentation
    public internal(set) var documentation: RichDefDocs

    /// Create from a gathered definition
    public init?(moduleName: String, passIndex: Int, gatherDef: GatherDef, uniquer: StringUniquer) {
        guard let name = gatherDef.sourceKittenDict[SwiftDocKey.name.rawValue] as? String,
            let kind = gatherDef.kind else {
            // XXX wrn - lots to add here tho, leave for now
            logWarning("Incomplete def, ignoring -- missing name")
            return nil
        }
        let children = gatherDef.children.asDefItems(moduleName: moduleName,
                                                     passIndex: passIndex,
                                                     uniquer: uniquer)
        self.moduleName = moduleName
        self.passIndex = passIndex
        self.defKind = kind

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
        documentation = RichDefDocs(gatherDef.translatedDocs)

        super.init(name: name, slug: uniquer.unique(name.slugged), children: children)
    }

    /// Used to create the `decls-json` product.
    public override func encode(to encoder: Encoder) throws {
        try doEncode(to: encoder)
    }

    /// Visitor
    override func accept(visitor: ItemVisitor, parents: [Item]) {
        visitor.visit(defItem: self, parents: parents)
    }

    override var kind: ItemKind { defKind.metaKind }

    override var showInToc: ShowInToc {
        // Always show nominal types/extensions, however nested.
        // (nesting can be natural or due to custom categories.)
        if defKind.metaKind == .extension ||
            defKind.metaKind == .type {
            return .yes
        }
        // Only show functions etc. at the top level -- allows global
        // functions but suppresses members.
        return .atTopLevel
    }
}
