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
/// unique custom groups alongside kind-groups if present....
public struct Group: Configurable {
    let groupGuides: GroupGuides

    public init(config: Config) {
        groupGuides = GroupGuides(config: config)
        config.register(self)
    }

    public func group(merged: [DefItem]) throws -> [Item] {
        // Cache kind:def while preserving order
        var kindToDefs = [ItemKind : [Item]]()
        merged.forEach { def in
            kindToDefs.reduceKey(def.defKind.metaKind, [def], { $0 + [def] })
        }
        let guides = try groupGuides.discoverGuides()
        if !guides.isEmpty {
            kindToDefs[.guide] = guides
        }

        // Create the groups
        let kindGroups = ItemKind.allCases.compactMap { kind -> GroupItem? in
            guard let defsToGroup = kindToDefs[kind] else {
                return nil
            }
            // topics, topic-merging
            return GroupItem(kind: kind, contents: defsToGroup)
        }
        return kindGroups
    }
}
