//
//  GroupItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// A list-of-things group page in the docs

public final class GroupItem: Item {
    // abstract

    /// Create a new group based on the type of content, eg. 'All guides'.
    public init(kind: ItemKind, contents: [Item]) {
        super.init(name: kind.name, slug: kind.name, title: kind.title, children: contents)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) {
        visitor.visit(groupItem: self, parents: parents)
    }

    public override var kind: ItemKind { .group }

    public override var showInToc: ShowInToc { .yes }
}
