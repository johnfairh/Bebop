//
//  GroupCustom.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Yams

/// Module to manage custom groups (custom categories as-was).
///
/// Big syntax validation during `checkOptions` phase, handle all the yaml down to data structures.
///
/// Then run over the simple data structure when it's time, matching up `Item`s from the forest and creating
/// `GroupItem`s as required.
///
final class GroupCustom: Configurable {
    private let customGroupsOpt = YamlOpt(y: "custom_groups")
    private let customCategoriesAlias: AliasOpt

    private(set) var groups = [Group]()

    init(config: Config) {
        customCategoriesAlias = AliasOpt(realOpt: customGroupsOpt, l: "custom-categories")
        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        if let customGroupsYaml = customGroupsOpt.value {
            logDebug("Group: start parsing custom_groups")
            groups = try GroupParser.groups(yaml: customGroupsYaml)
            logDebug("Group: done parsing custom_groups: \(groups)")
        }
    }

    /// Create custom groups from the config file data structure.
    /// Return the groups created
    /// Return a list of leftover items that need to be included in kind groups.
    /// Give a warning if there are references to stuff we don't understand.
    func createGroups(items: [Item], uniquer: StringUniquer) -> (grouped: [GroupItem], ungrouped: [Item]) {
        guard !groups.isEmpty else {
            return (grouped: [], ungrouped: items)
        }

        let index = Index(items: items)
        let builder = Builder(index: index, uniquer: uniquer)
        return (grouped: groups.map { builder.build(group: $0) },
                ungrouped: index.remainingItems)
    }

    // MARK: Model

    /// The data structure parsed out of the custom_groups yaml is an array of these
    struct Group: Equatable {
        let name: Localized<String>
        let abstract: Localized<String>?
        let topics: [Topic]

        struct Topic: Equatable {
            let topic: J2Lib.Topic
            let children: [Item]
        }

        enum Item: Equatable {
            case name(String)
            case group(Group)
        }
    }

    /// The data structure parsed out of the custom_defs yaml is an array of these
    struct Def: Equatable {
        let name: String
        let skipUnlisted: Bool
        let topics: [Topic]

        struct Topic: Equatable {
            let topic: J2Lib.Topic
            let children: [String]
        }
    }

    // MARK: Index

    /// A name-indexed lookup of all the Items used to populate the custom group tree
    final class Index {
        private var nameMap = [String: Item]()
        private var moduleNameMap = [String: Item]()

        init(items: [Item]) {
            items.forEach { add(item: $0) }
        }

        /// Store qualified names of defs too so we can handle ModuleA.Foo and ModuleB.Foo.
        private func add(item: Item) {
            nameMap[item.name] = item
            if let defItem = item as? DefItem {
                moduleNameMap[defItem.nameInModule] = item
            }
        }

        /// Remove items from our caches as they are used - no dups
        func find(name: String) -> Item? {
            guard let item = moduleNameMap[name] ?? nameMap[name] else {
                return nil
            }
            nameMap.removeValue(forKey: item.name)
            if let defItem = item as? DefItem {
                moduleNameMap.removeValue(forKey: defItem.nameInModule)
            }
            return item
        }

        /// What's left are processed by the 'group-by-kind' path.
        var remainingItems: [Item] {
            Array(nameMap.values)
        }
    }

    // MARK: Builder

    /// Worker to run over the data structure and produce `GroupItem`s with other items
    /// dangling off them.
    final class Builder {
        private var index: Index
        private let uniquer: StringUniquer

        init(index: Index, uniquer: StringUniquer) {
            self.index = index
            self.uniquer = uniquer
        }

        func build(group: Group) -> GroupItem {
            GroupItem(kind: .custom(group.name),
                      abstract: group.abstract,
                      contents: build(topics: group.topics),
                      uniquer: uniquer)
        }

        func build(topics: [Group.Topic]) -> [Item] {
            topics.flatMap { topic -> [Item] in
                let items = topic.children.compactMap { build(item: $0) }
                items.forEach { $0.topic = topic.topic }
                return items
            }
        }

        func build(item: Group.Item) -> Item? {
            switch item {
            case .name(let name):
                guard let theItem = index.find(name: name) else {
                    logWarning("Can't resolve item name '\(name)' inside 'custom_groups', ignoring.")
                    return nil
                }
                return theItem
            case .group(let group):
                return build(group: group)
            }
        }
    }

    // MARK: Parser

    /// Recursive yaml parser for custom groups & topics structure
    private struct GroupParser {
        let nameOpt = LocStringOpt(y: "name")
        let abstractOpt = LocStringOpt(y: "abstract")
        let childrenOpt = YamlOpt(y: "children")
        let topicsOpt = YamlOpt(y: "topics")
        let skipUnlistedOpt = BoolOpt(y: "skip_unlisted")

        private func parse(yaml: Yams.Node, context: String) throws {
            let mapping = try yaml.checkMapping(context: context)
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            // common error checks
            if !nameOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpName, try yaml.asDebugString()))
            }
            if childrenOpt.configured && topicsOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpBoth, try yaml.asDebugString()))
            }
            // XXX
            if skipUnlistedOpt.value && !topicsOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpUnlisted, try yaml.asDebugString()))
            }
        }

        /// Try to parse one `Group` out of the mapping
        func group(yaml: Yams.Node, context: String) throws -> Group {
            try parse(yaml: yaml, context: context)

            let topics: [Group.Topic]

            if childrenOpt.configured {
                topics = [.init(topic: Topic(), children: try items())]
            } else if let topicsYaml = topicsOpt.value {
                topics = try GroupParser.topics(yaml: topicsYaml)
            } else {
                topics = []
            }
            return Group(name: nameOpt.value!,
                         abstract: abstractOpt.value,
                         topics: topics)
        }

        /// Try to parse a `Group.Topic` out of the yaml
        func topic(yaml: Yams.Node, context: String) throws -> Group.Topic {
            try parse(yaml: yaml, context: context)
            if topicsOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpNested, try yaml.asDebugString()))
            }
            return Group.Topic(topic: Topic(title: nameOpt.value!,
                                            body: abstractOpt.value),
                               children: try items())
        }

        /// Takes from `childrenOpt`,
        private func items() throws -> [Group.Item] {
            guard let childrenYaml = childrenOpt.value else {
                return []
            }
            let childrenSequence = try childrenYaml.checkSequence(context: "topics.children")
            return try childrenSequence.map { childYaml in
                if let childScalar = childYaml.scalar {
                    return .name(childScalar.string)
                }
                return .group(try GroupParser().group(yaml: childYaml, context: "topics.children[n]"))
            }
        }

        // MARK: Factory

        /// Try to parse a list of `Group`s out of the yaml
        static func groups(yaml: Yams.Node) throws -> [Group] {
            try yaml.checkSequence(context: "custom_groups").map { groupYaml in
                try GroupParser().group(yaml: groupYaml, context: "custom_groups[]")
            }
        }

        /// Try to parse a list of `Group.Topic`s out of the yaml
        static func topics(yaml: Yams.Node) throws -> [Group.Topic] {
            try yaml.checkSequence(context: "topics").map { topicYaml in
                try GroupParser().topic(yaml: topicYaml, context: "topics[]")
            }
        }
    }
}

// MARK: CustomStringConvertible

extension GroupCustom.Group: CustomStringConvertible {
    var description: String {
        var line = "Grp name=\(name.first!.value)"
        if let abstract = abstract {
            line += " abstract=\(abstract.first!.value)"
        }
        if !topics.isEmpty {
            line += " topics=[\(topics)]"
        }
        return line
    }
}

extension GroupCustom.Group.Topic: CustomStringConvertible {
    var description: String {
        var line = "Tpc \(topic)"
        if !children.isEmpty {
            line += " children=[\(children)]"
        }
        return line
    }
}

extension GroupCustom.Group.Item: CustomStringConvertible {
    var description: String {
        switch self {
        case .name(let str): return str
        case .group(let grp): return grp.description
        }
    }
}

// MARK: DefItem

private extension DefItem {
    /// Qualified name --- valid only for the top-level types that we expect to be dealing with.
    var nameInModule: String {
        precondition(parent == nil)
        return "\(location.moduleName).\(name)"
    }
}
