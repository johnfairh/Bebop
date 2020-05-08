//
//  GroupItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Kinds of groups
public enum GroupKind: Hashable {
    /// All items of a particular kind.  Named after that kind.
    case allItems(ItemKind)
    /// Items of a particular kind from a module
    case moduleItems(ItemKind, Localized<String>)
    /// Some items of a particular kind, with a name to differentiate them
    case someItems(ItemKind, Localized<String>)
    /// Some collection of items with a name and a language-mixing policy
    case custom(Localized<String>, Bool)
    /// A collection of items with a shared filesystem path
    case path(String)

    /// The kind of the group, if it is known
    public var kind: ItemKind? {
        switch self {
        case .allItems(let k),
             .moduleItems(let k, _),
             .someItems(let k, _): return k
        case .custom(_, _),
             .path(_): return nil
        }
    }

    public var isCustom: Bool {
        if case .custom(_, _) = self {
            return true
        }
        return false
    }

    public var mixLanguages: Bool {
        guard case let .custom(_, mix) = self else {
            return false
        }
        return mix
    }

    public var includesModuleName: Bool {
        switch self {
        case .moduleItems(_, _): return true
        default: return false
        }
    }

    public func title(in language: DefLanguage) -> Localized<String> {
        switch self {
        case .allItems(let k): return k.title(in: language)
        case .moduleItems(let k, let n),
             .someItems(let k, let n): return k.title(in: language, affix: n)
        case .custom(let t, _): return t
        case .path(let title): return .init(unlocalized: title)
        }
    }
}

// A list-of-things group page in the docs

public final class GroupItem: Item {
    public let groupKind: GroupKind
    public internal(set) var customAbstract: RichText?

    /// Create a new group with a name derived from the kind
    init(kind: GroupKind, abstract: Localized<String>? = nil, contents: [Item], uniquer: StringUniquer) {
        self.groupKind = kind
        self.customAbstract = abstract.flatMap { RichText($0) }
        let name = groupKind.title(in: .swift).get(Localizations.shared.main.tag)
        super.init(name: name,
                   slug: uniquer.unique(name.slugged),
                   children: contents)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) throws {
        try visitor.visit(groupItem: self, parents: parents)
    }

    public override var kind: ItemKind { .group }
    public override var dashKind: String { "Category" }

    public override func title(for language: DefLanguage) -> Localized<String> {
        groupKind.title(in: language)
    }

    public override var showInToc: ShowInToc { .yes }

    override func format(formatters: RichText.Formatters) {
        customAbstract?.format(formatters.block)
    }
}
