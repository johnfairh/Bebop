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
            let group = GroupItem(kind: kind, contents: defsToGroup)
            group.rationalizeTopics()
            return group
        }
        return kindGroups
    }
}

extension Item {
    /// Sort out the topics of items to get rid of dups or weird gaps and make sure everything
    /// has a topic.  Probably only needed when the topics come from MARK comments in jazzy mode.
    func rationalizeTopics() {
        guard let firstChild = children.first else {
            return
        }
        // Start an empty topic if there is none
        var currentTopic = firstChild.topic ?? Topic()
        children.forEach { child in
            child.rationalizeTopics()
            guard let childTopic = child.topic else {
                // add to current topic
                child.topic = currentTopic
                return
            }
            if childTopic === currentTopic {
                // already there
                return
            }
            if childTopic == currentTopic {
                // textual dup (different file origin/sorting artefact?), merge
                child.topic = currentTopic
                return
            }
            // New topic!
            currentTopic = childTopic
        }
    }
}

/// How the defs from a module are supposed to be organized in the docs
public enum ModuleGroupPolicy: Hashable {
    /// Merge this module into a default group with others that share the setting
    case global
    /// Keep this module separate from all the others
    case separate
    /// Merge this module into a named group along with others that share the setting
    case group(Localized<String>)

    init(merge: Bool, name: Localized<String>? = nil) {
        if let name = name {
            precondition(merge)
            self = .group(name)
        } else if merge {
            self = .global
        } else {
            self = .separate
        }
    }
}
