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
    /// The name of the item in its scope, eg. a class name or a guide name
    public let name: String
    /// The item's slug, unique in its docs scope
    public let slug: String
    /// Children in the documentation tree
    public let children: [Item]

    /// The path of the item's URL, relative to docroot, without a file extension.  URL-encoded.
    public internal(set) var urlPath: String = ""
    /// The hash of the item's URL, or `nil` if it has its own page
    public internal(set) var urlHash: String? = nil

    public init(name: String, slug: String, children: [Item]) {
        self.name = name
        self.slug = slug
        self.children = children
    }

    /// Overridden
    func accept(visitor: ItemVisitor, parents: [Item]) { preconditionFailure() }
    var  kind: ItemKind { .other }


    private enum CodingKeys: CodingKey {
        case name
        case children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(children, forKey: .children)
    }
}
