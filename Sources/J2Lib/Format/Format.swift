//
//  Format.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public struct Format: Configurable {
    public init(config: Config) {
        config.register(self)
    }

    public func format(items: [Item]) throws -> [Item] {
        URLVisitor().walk(items: items)
        MarkdownVisitor().walk(items: items)
        return items
    }
}


struct MarkdownVisitor: ItemVisitor {
    func visit(defItem: DefItem, parents: [Item]) {
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
    }
}
