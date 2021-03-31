//
//  Def.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// The base class of things that appear in the documentation tree.
///
/// Encodable support is for creating the `decls-json` product post-Merge.
public class Item: Encodable {
    /// The name of the item in its scope, eg. a class name or a guide name
    public let name: String
    /// The item's slug, unique in its docs scope
    public let slug: String
    /// Children in the documentation tree
    public internal(set) var children: [Item] {
        didSet {
            children.forEach { $0.parent = self }
        }
    }
    /// Parent in the documentation tree
    public private(set) weak var parent: Item?
    /// Topic the item belongs to
    public internal(set) var topic: Topic?
    /// Linear previous and next nodes in the documentation page tree
    public internal(set) weak var linearPrev: Item?
    public internal(set) weak var linearNext: Item?

    /// Info about the item's URL relative to the docroot
    public internal(set) var url: URLPieces

    init(name: String, slug: String, children: [Item] = []) {
        self.name = name
        self.slug = slug
        self.children = children
        self.url = URLPieces()
    }

    /// Get the list of items that lead to this one, index 0 is the most root, index -1 is our direct parent
    public var parentsFromRoot: [Item] {
        var parents = [Item]()
        var item = self
        while let parent = item.parent {
            parents.append(parent)
            item = parent
        }
        return parents.reversed()
    }

    /// Overridden
    public func accept(visitor: ItemVisitorProtocol, parents: [Item]) throws { preconditionFailure() }
    public var  kind: ItemKind { .other }
    public var  dashKind: String { "" }

    /// The item's title, translated, for objc or swift.
    public func title(for language: DefLanguage) -> Localized<String>? {
        return nil
    }

    /// The item's title, preferring a particular language but guaranteed to return something.
    public func titlePreferring(language: DefLanguage) -> Localized<String> {
        title(for: language) ?? title(for: language.otherLanguage)!
    }

    /// Get a name that makes sense to sort by - omits syntax and types
    public var sortableName: String {
        name
    }

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

    /// Does the item have a special name for use in the table of contents?
    public var tocName: String?

    /// Format the item's associated text data
    func format(formatters: RichText.Formatters) {
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
