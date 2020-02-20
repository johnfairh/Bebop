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
    /// Topic the item belongs to
    public internal(set) var topic: Topic?

    /// Info about the item's URL relative to the docroot
    public internal(set) var url: URLPieces

    public init(name: String, slug: String, children: [Item] = []) {
        self.name = name
        self.slug = slug
        self.children = children
        self.url = URLPieces()
    }

    /// Overridden
    public func accept(visitor: ItemVisitorProtocol, parents: [Item]) { preconditionFailure() }
    public var  kind: ItemKind { .other }

    /// The item's title, translated, for objc or swift
    public var swiftTitle: Localized<String>? { return nil }
    public var objCTitle: Localized<String>? { return nil }
    //    public var title: Localized<String> {
    //        swiftTitle ?? objCTitle ?? preconditionFailure()
    //    }

    /// Does the item show in the table of contents?
    public enum ShowInToc {
        /// Alway show in ToC
        case yes
        /// Never show in ToC
        case no
        /// Only show at the outermost level
        case atTopLevel
    }
    public var showInToc: ShowInToc {
        .no
    }

    /// Format the item's associated text data
    public func format(blockFormatter: RichText.Formatter,
                       inlineFormatter: RichText.Formatter) rethrows {
    }

    // Encodable

    private enum CodingKeys: CodingKey {
        case name
        case title
        case children
        case topic
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(children, forKey: .children)
        if let topic = topic {
            try container.encode(topic, forKey: .topic)
        }
    }
}
