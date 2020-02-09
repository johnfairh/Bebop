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
    /// The item's translated title
    public let title: Localized<String>
    /// Children in the documentation tree
    public let children: [Item]

    /// Info about the item's URL relative to the docroot
    public internal(set) var url: URLPieces

    public init(name: String, slug: String, title: Localized<String>? = nil, children: [Item]) {
        self.name = name
        self.slug = slug
        if let title = title {
            self.title = title
        } else {
            self.title = Localized<String>(unLocalized: name)
        }
        self.children = children
        self.url = URLPieces()
    }

    /// Overridden
    func accept(visitor: ItemVisitor, parents: [Item]) { preconditionFailure() }
    var  kind: ItemKind { .other }

    /// Does the item show in the table of contents?
    public enum ShowInToc {
        /// Alway show in ToC
        case yes
        /// Never show in ToC
        case no
        /// Only show at the outermost level
        case atTopLevel
    }
    var showInToc: ShowInToc { .no }

    // Encodable

    private enum CodingKeys: CodingKey {
        case name
        case title
        case children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(children, forKey: .children)
    }
}

