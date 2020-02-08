//
//  GroupItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public enum GroupType {
    case kind(ItemKind)
    case custom(name: Localized<String>)
}

// A list-of-things group page in the docs

public final class GroupItem: Item {
    public let type: GroupType // not sure this is useful actually once constructed
    // abstract

    public init(kind: ItemKind, contents: [Item]) {
        self.type = .kind(kind)
        super.init(name: kind.name["en"] ?? String(describing: kind), children: contents)
    }
}
