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
    /// Some collection of items with a name
    case custom(Localized<String>)

    /// The kind of the group, if it is known
    public var kind: ItemKind? {
        switch self {
        case .allItems(let k),
             .moduleItems(let k, _),
             .someItems(let k, _): return k
        case .custom(_): return nil
        }
    }

    public var isCustom: Bool {
        kind == nil
    }

    public var includesModuleName: Bool {
        switch self {
        case .moduleItems(_): return true
        default: return false
        }
    }

    public func title(in language: DefLanguage) -> Localized<String> {
        switch self {
        case .allItems(let k): return k.title(in: language)
        case .moduleItems(let k, let n),
             .someItems(let k, let n): return k.title(in: language, affix: n)
        case .custom(let t): return t
        }
    }
}

// A list-of-things group page in the docs

public final class GroupItem: Item {
    public let groupKind: GroupKind
    public internal(set) var customAbstract: RichText?

    /// Create a new group based on the type of content, eg. 'All guides'.
    init(kind: GroupKind, abstract: Localized<String>? = nil, contents: [Item], uniquer: StringUniquer) {
        self.groupKind = kind
        self.customAbstract = abstract.flatMap { RichText($0) }
        let name = groupKind.title(in: .swift).get(Localizations.shared.main.tag)
        super.init(name: name,
                   slug: uniquer.unique(name.slugged),
                   children: contents)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) {
        visitor.visit(groupItem: self, parents: parents)
    }

    public override var kind: ItemKind { .group }

    public override func title(for language: DefLanguage) -> Localized<String> {
        groupKind.title(in: language)
    }

    public override var showInToc: ShowInToc { .yes }

    override func format(formatters: RichText.Formatters) {
        customAbstract?.format(formatters.block)
    }
}
