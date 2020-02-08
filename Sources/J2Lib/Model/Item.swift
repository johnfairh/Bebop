//
//  Def.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

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

/// Most-top level categorization of definitions
public enum ItemKind: String, CaseIterable {
    case guide
    case type
    case variable
    case function
    case `extension`
    case group     // what is this actually for?
    case other

    var name: Localized<String> {
        switch self {
        case .guide: return .localizedOutput(.guides)
        case .type: return .localizedOutput(.types)
        case .variable: return .localizedOutput(.variables)
        case .function: return .localizedOutput(.functions)
        case .extension: return .localizedOutput(.extensions)
        default: return .localizedOutput(.others)
        }
    }
}
