//
//  Group.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `Group` arranges `DefItems` into a hierarchy of `Items` suitable for documentation generation
///  by injecting guides and creating sections.
///
/// - discard stuff that didn't actually get compiled
/// - merge duplicates, combining availability
/// - resolve extensions and categories
///
/// This is the end of the sourcekit-style hashes, converted into more well-typed `Item` hierarchy.
public struct Group {
    public init(config: Config) {
    }

    public func group(merged: [DefItem]) throws -> [Item] {
        // Cache kind:def while preserving order
        var kindToDefs: [ItemKind : [DefItem]] = [:]
        merged.forEach { def in
            if var list = kindToDefs[def.kind.metaKind] {
                list.append(def)
                kindToDefs[def.kind.metaKind] = list
            } else {
                kindToDefs[def.kind.metaKind] = [def]
            }
        }
        // Create the groups
        let kindGroups = ItemKind.allCases.compactMap { kind -> Item? in
            guard let defsToGroup = kindToDefs[kind] else {
                return nil
            }
            // topics, topic-merging
            return GroupItem(kind: kind, contents: defsToGroup)
        }
        return kindGroups
    }
}
