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
    let published: Config.Published // modulename -> grouppolicy

    public init(config: Config) {
        customCatPrefixAlias = AliasOpt(realOpt: customGroupPrefixOpt, l: "custom-categories-unlisted-prefix")
        hideUnlistedDocsAlias = AliasOpt(realOpt: excludeUnlistedGuidesOpt, l: "hide-unlisted-documentation")
        groupGuides = GroupGuides(config: config)
        groupCustom = GroupCustom(config: config)
        published = config.published
        config.register(self)
    }

    public func checkOptions(published: Config.Published) throws {
        published.sourceOrderDefs = topicStyle != .logical
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
        let kindGroups = createKindGroups(items: ungrouped,
                                          uniquer: uniquer,
                                          customPrefix: customPrefix,
                                          excludeGuides: excludeGuides)

        // All items now assigned to groups
        let allGroups = customGroups + kindGroups

        // Sort out topics, arrange items inside defs
        let topicVisitor = TopicCreationVisitor(style: topicStyle, customizer: { def in
            self.groupCustom.customizeTopics(defItem: def)
        })
        topicVisitor.walk(items: allGroups)

        return allGroups
    }

    /// Create groups from the items using default rules, grouping types etc. together
    /// and taking heed of the multi-module rules governing grouping types from different modules.
    ///
    /// Why is this such a mess!?
    public func createKindGroups(items: [Item], uniquer: StringUniquer, customPrefix: Localized<String>?, excludeGuides: Bool) -> [GroupItem] {
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

}

/// Sort order for groups.  Specific before generic.
/// Sorting by kind itself is outside of this, according to the ItemKind enum order.
extension GroupKind: Comparable {
    private var sortKey: String {
        switch self {
        case .allItems: return ""
        case .someItems(_, let name),
             .moduleItems(_, let name): return name.get(Localizations.shared.main.tag)
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
