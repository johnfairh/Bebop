//
//  Group.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SortedArray

/// How the defs from a module are supposed to be organized in the docs
enum ModuleGroupPolicy: Hashable {
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

/// Style of grouping items not covered by custom groups
enum GroupStyle: String, CaseIterable {
    // Group items by kind
    case kind
    // Group items by their filesystem position
    case path
}

/// `Group` arranges `DefItems` into a hierarchy of `Items` suitable for documentation generation
///  by injecting guides and creating groups.
///
public struct Group: Configurable {
    let groupStyleOpt = EnumOpt<GroupStyle>(l: "group-style").def(.kind)
    var groupStyle: GroupStyle {
        groupStyleOpt.value!
    }
    let topicStyleOpt = EnumOpt<TopicStyle>(l: "topic-style").def(.logical)
    var topicStyle: TopicStyle {
        topicStyleOpt.value!
    }
    let customGroupPrefixOpt = LocStringOpt(y: "custom_groups_unlisted_prefix")
    let excludeUnlistedGuidesOpt = BoolOpt(l: "exclude-unlisted-guides")

    let customCatPrefixAlias: AliasOpt
    let hideUnlistedDocsAlias: AliasOpt

    let groupGuides: GroupGuides
    let groupCustom: GroupCustom
    let published: Published // modulename -> grouppolicy

    public init(config: Config) {
        customCatPrefixAlias = AliasOpt(realOpt: customGroupPrefixOpt, l: "custom-categories-unlisted-prefix")
        hideUnlistedDocsAlias = AliasOpt(realOpt: excludeUnlistedGuidesOpt, l: "hide-unlisted-documentation")
        groupGuides = GroupGuides(config: config)
        groupCustom = GroupCustom(config: config)
        published = config.published
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        publish.sourceOrderDefs = topicStyle != .logical
    }

    public func group(merged: [DefItem]) throws -> [Item] {
        logDebug("Group: Discovering guides")
        let guides = try groupGuides.discoverGuides()
        logDebug("Group: Discovered \(guides.count) guides.")

        let allItems = merged + guides

        // For the group page names, which all end up in site root
        let uniquer = StringUniquer()

        let (customGroups, ungrouped) = groupCustom.createGroups(items: allItems, uniquer: uniquer)
        let customPrefix = customGroupPrefixOpt.value.flatMap { customGroups.isEmpty ? nil : $0 }
        let excludeGuides = !customGroups.isEmpty && excludeUnlistedGuidesOpt.value
        let otherGroups: [GroupItem]
        switch groupStyle {
        case .kind:
            otherGroups = createKindGroups(items: ungrouped,
                                           uniquer: uniquer,
                                           customPrefix: customPrefix,
                                           excludeGuides: excludeGuides)
        case .path:
            otherGroups = createPathGroups(items: ungrouped,
                                           uniquer: uniquer,
                                           customPrefix: customPrefix,
                                           excludeGuides: excludeGuides)
        }

        // All items now assigned to groups
        let allGroups = customGroups + otherGroups

        // Sort out topics, arrange items inside defs
        let topicVisitor = TopicCreationVisitor(style: topicStyle, customizer: { def in
            self.groupCustom.customizeTopics(defItem: def)
        })
        try topicVisitor.walk(items: allGroups)

        return allGroups
    }

    /// Create groups from the items using default rules, grouping types etc. together
    /// and taking heed of the multi-module rules governing grouping types from different modules.
    ///
    /// Why is this such a mess!?
    func createKindGroups(items: [Item], uniquer: StringUniquer, customPrefix: Localized<String>?, excludeGuides: Bool) -> [GroupItem] {
        logDebug("Group: grouping leftovers by kind")
        // Cache kind:def while preserving order
        var kindToDefs = [GroupKind : [Item]]()
        items.forEach { item in
            if let def = item as? DefItem {
                let moduleName = def.location.moduleName
                var groupPolicy = published.module(moduleName).groupPolicy
                if groupPolicy == .separate && !published.isMultiModule {
                    groupPolicy = .global
                }
                let groupName = GroupKind(kind: def.defKind.metaKind,
                                          moduleName: moduleName,
                                          policy: groupPolicy,
                                          customPrefix: customPrefix)

                kindToDefs.reduceKey(groupName, [def], { $0 + [def] })
                Stats.inc(.groupIncludedDefsByKind)
            } else if let guide = item as? GuideItem {
                if excludeGuides {
                    logDebug("Group: Excluding guide \(item.name) due to exclude-unlisted-guides")
                    Stats.inc(.groupExcludedGuidesByKind)
                } else {
                    let guideGroupKind = GroupKind(kind: .guide, policy: .global, customPrefix: customPrefix)
                    kindToDefs.reduceKey(guideGroupKind, [guide], { $0 + [guide] })
                    Stats.inc(.groupIncludedGuidesByKind)
                }
            }
        }

        // Create the groups

        return ItemKind.allCases.flatMap { kind -> [GroupItem] in
            let groupsForKind = kindToDefs
                .filter { $0.key.kind == kind }
                .sorted { $0.key < $1.key }

            return groupsForKind.map { kv in
                Stats.inc(.groupsByKind)
                return GroupItem(kind: kv.key, contents: kv.value, uniquer: uniquer)
            }
        }
    }

    /// Create groups from the items using their source filesystem position.
    /// Fall back to kind groups for stuff without a source location.
    /// This should maybe be respecting merge-modules etc?  Need to see for real.
    func createPathGroups(items: [Item], uniquer: StringUniquer, customPrefix: Localized<String>?, excludeGuides: Bool) -> [GroupItem] {
        logDebug("Group: grouping leftovers by path")
        let (pathedItems, unpathedItems) = items.splitPartition { $0.pathname != nil }

        // Group by directory
        var pathToItems = [String: [Item]]()
        pathedItems.forEach { item in
            let itemPathURL = URL(fileURLWithPath: item.pathname!)
            pathToItems.reduceKey(itemPathURL.deletingLastPathComponent().path, [item], { $0 + [item] })
        }

        // Wrap up in a class for ref semantics as we reparent...
        final class PathItems {
            let path: String
            var nestingDepth: Int {
                path.directoryNestingDepth
            }
            var items: [Item]
            init(_ path: String, _ items: [Item]) {
                self.path = path
                self.items = items
            }
        }

        // Order from long paths to short - earlier in list cannot have parent preceding
        var pathItemsList = pathToItems
            .map( { PathItems($0.key, $0.value) })
            .sorted { $0.nestingDepth > $1.nestingDepth }

        var groups = SortedArray<GroupItem>() { $0.name < $1.name }

        while !pathItemsList.isEmpty {
            let next = pathItemsList.removeFirst()
            // Because of sort, first path that is our prefix is our parent
            if let parent = pathItemsList.first(where: { next.path.hasPrefix($0.path) }) {
                // Name it for the intervening path parts without a leading slash (sorry Windows)
                let groupName = String(next.path.dropFirst(parent.path.count)).re_sub("^/", with: "")
                let group = GroupItem(kind: .path(groupName), contents: next.items, uniquer: uniquer)
                parent.items.append(group)
            } else {
                // No parent - must be a top-level directory.  Name it after the directory.
                let groupName = String(next.path.split(separator: "/").last!)
                let group = GroupItem(kind: .path(groupName), contents: next.items, uniquer: uniquer)
                groups.insert(group)
            }
        }

        let kindGroups = createKindGroups(items: unpathedItems, uniquer: uniquer, customPrefix: customPrefix, excludeGuides: excludeGuides)
        return Array(groups) + kindGroups
    }
}

private extension Item {
    var pathname: String? {
        (self as? DefItem)?.location.filePathname
    }
}

/// Sort order for groups.  Specific before generic.
/// Sorting by kind itself is outside of this, according to the ItemKind enum order.
/// (actually I don't think this ends up really used anywhere - should revisit and simplify)
extension GroupKind : Comparable {
    private var sortKey: String {
        switch self {
        case .allItems: return ""
        case .someItems(_, let name),
             .moduleItems(_, let name): return name.get(Localizations.shared.main.tag)
        case .custom(let title, _): return title.get(Localizations.shared.main.tag)
        case .path(let name): return name
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

private extension GroupKind {
    /// Convert from module info to group kind.
    ///
    /// `customPrefix` support is half-hearted, but I'm not sure it's too useful and the default is more
    /// sensible (no prefix).  Really the missing combo is module-separate plus custom-prefix where we
    /// need a new path and localization hell to slot in both terms somehow.
    init(kind: ItemKind, moduleName: String = "", policy: ModuleGroupPolicy, customPrefix: Localized<String>?) {
        switch policy {
        case .global:
            if let customPrefix = customPrefix {
                self = .someItems(kind, customPrefix)
            } else {
                self = .allItems(kind)
            }
        case .separate:
            self = .moduleItems(kind, Localized<String>(unlocalized: moduleName))
        case .group(let title):
            self = .someItems(kind, title)
        }
    }
}
