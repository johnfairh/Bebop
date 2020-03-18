//
//  Group.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

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

/// `Group` arranges `DefItems` into a hierarchy of `Items` suitable for documentation generation
///  by injecting guides and creating groups.
///
public struct Group: Configurable {
    let groupGuides: GroupGuides
    let published: Config.Published // need the modulename -> grouppolicy map

    public init(config: Config) {
        groupGuides = GroupGuides(config: config)
        published = config.published
        config.register(self)
    }

    public func group(merged: [DefItem]) throws -> [Item] {
        logDebug("Group: Discovering guides")
        let guides = try groupGuides.discoverGuides()
        logDebug("Group: Discovered \(guides.count) guides.")

        let allItems = merged + guides

        // This is the uniquer for the group page names, which all end up in the root of the site
        let groupUniquer = StringUniquer()

        return createKindGroups(items: allItems, uniquer: groupUniquer)
    }

    public func createKindGroups(items: [Item], uniquer: StringUniquer) -> [GroupItem] {
        // Cache kind:def while preserving order
        var kindToDefs = [GroupKind : [Item]]()
        items.forEach { item in
            if let def = item as? DefItem {
                let moduleName = def.location.moduleName
                var groupPolicy = published.moduleGroupPolicy[moduleName] ?? .separate
                if groupPolicy == .separate && !published.isMultiModule {
                    groupPolicy = .global
                }
                let groupName = GroupKind(kind: def.defKind.metaKind,
                                          moduleName: moduleName,
                                          policy: groupPolicy)

                kindToDefs.reduceKey(groupName, [def], { $0 + [def] })
            } else if let guide = item as? GuideItem {
                kindToDefs.reduceKey(.allItems(.guide), [guide], { $0 + [guide] })
            }
        }

        // Create the groups
        return ItemKind.allCases.flatMap { kind -> [GroupItem] in
            let groupsForKind = kindToDefs
                .filter { $0.key.kind == kind }
                .sorted { $0.key < $1.key }

            return groupsForKind.map { kv in
                let group = GroupItem(kind: kv.key, contents: kv.value, uniquer: uniquer)
                group.rationalizeTopics()
                return group
            }
        }
    }
}

/// Sort order for groups.  Specific before generic.
/// Sorting by kind itself is outside of this, according to the ItemKind enum order.
extension GroupKind: Comparable {
    private var sortKey: String {
        switch self {
        case .allItems: return ""
        case .someItems(_, let name): return name.get(Localizations.shared.main.tag)
        case .custom(let title): return title.get(Localizations.shared.main.tag)
        }
    }

    public static func < (lhs: GroupKind, rhs: GroupKind) -> Bool {
        switch (lhs, rhs) {
        case (.allItems, _): return false
        case (_, .allItems): return true
        default: return lhs.sortKey < rhs.sortKey
        }
    }
}

extension GroupKind {
    /// Convert from module info to group kind.
    init(kind: ItemKind, moduleName: String, policy: ModuleGroupPolicy) {
        switch policy {
        case .global:
            self = .allItems(kind)
        case .separate:
            self = .someItems(kind, Localized<String>(unlocalized: moduleName))
        case .group(let title):
            self = .someItems(kind, title)
        }
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

