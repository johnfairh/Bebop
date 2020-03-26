//
//  GroupCustom.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Yams

/// Module to manage custom groups (custom categories as-was) and custom defs, which turned out
/// to be a different thing.
///
/// Big syntax validation during `checkOptions` phase, handle all the yaml down to data structures.
///
/// Then run over the simple data structure when it's time, matching up `Item`s from the forest and creating
/// `GroupItem`s as required.
///
/// For custom-defs, we are invoked by the topic visitor to see if we have an opinion on how a particular
/// def should be laid out.
final class GroupCustom: Configurable {
    private let customGroupsOpt = YamlOpt(y: "custom_groups")
    private let customDefsOpt = YamlOpt(y: "custom_defs")
    private let customCategoriesAlias: AliasOpt

    private(set) var groups = [Group]()
    private(set) var defs = [String : Def]()

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

        if let customDefsYaml = customDefsOpt.value {
            logDebug("Group: start parsing custom_defs")
            let defsList = try DefParser.defs(yaml: customDefsYaml)
            defsList.forEach { def in
                if defs[def.name] != nil {
                    logWarning(.localized(.wrnCustomDefDup, def.name))
                } else {
                    defs[def.name] = def
                }
            }
            logDebug("Group: done parsing custom_defs: \(defsList)")
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

    /// Implement `custom_defs`.
    ///
    /// If the def is covered by `custom_defs` then affected children
    /// are removed from  `defItem.children` and returned in order
    /// with topics.
    func customizeTopics(defItem: DefItem) -> [Item] {
        let qualifiedName = defItem.primaryFullyQualifiedName
        let nameInModule = defItem.location.moduleName + "." + qualifiedName
        guard let def = defs[qualifiedName] ?? defs[nameInModule] else {
            return []
        }
        logDebug("Group: Customizing def \(defItem.name) with \(def)")
        return def.apply(to: defItem)
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
                    logWarning(.localized(.wrnCustomGrpMissing, name))
                    return nil
                }
                return theItem
            case .group(let group):
                return build(group: group)
            }
        }
    }

    // MARK: Groups Parser

    /// Recursive yaml parser for custom groups & topics structure
    private struct GroupParser {
        let nameOpt = LocStringOpt(y: "name")
        let abstractOpt = LocStringOpt(y: "abstract")
        let childrenOpt = YamlOpt(y: "children")
        let topicsOpt = YamlOpt(y: "topics")

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
                                            overview: abstractOpt.value),
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

        /// Try to parse a list of `Group`s out of the yaml
        static func groups(yaml: Yams.Node) throws -> [Group] {
            try yaml.checkSequence(context: "custom_groups").map { groupYaml in
                try GroupParser().group(yaml: groupYaml, context: "custom_groups[]")
            }
        }

        /// Try to parse a list of `Group.Topic`s out of the yaml
        static func topics(yaml: Yams.Node) throws -> [Group.Topic] {
            try yaml.checkSequence(context: "custom_groups.topics").map { topicYaml in
                try GroupParser().topic(yaml: topicYaml, context: "custom_groups.topics[]")
            }
        }
    }

    // MARK: Defs Parser

    /// Yaml parser for custom defs & topics structure
    private struct DefParser {
        let nameOpt = StringOpt(y: "name")
        let skipUnlistedOpt = BoolOpt(y: "skip_unlisted")
        let topicsOpt = YamlOpt(y: "topics")

        func def(yaml: Yams.Node) throws -> Def {
            let mapping = try yaml.checkMapping(context: "custom_defs[]")
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            guard let name = nameOpt.value else {
                throw OptionsError(.localized(.errCfgCustomDefName, try yaml.asDebugString()))
            }
            guard let topicsYaml = topicsOpt.value else {
                throw OptionsError(.localized(.errCfgCustomDefTopics, try yaml.asDebugString()))
            }

            return Def(name: name,
                       skipUnlisted: skipUnlistedOpt.value,
                       topics: try TopicParser.topics(yaml: topicsYaml))
        }

        /// Try to parse a list of `Def`s out of the yaml
        static func defs(yaml: Yams.Node) throws -> [Def] {
            try yaml.checkSequence(context: "custom_defs").map { defYaml in
                try DefParser().def(yaml: defYaml)
            }
        }

        struct TopicParser {
            let nameOpt = LocStringOpt(y: "name")
            let abstractOpt = LocStringOpt(y: "abstract")
            let childrenOpt = StringListOpt(y: "children")

            func topic(yaml: Yams.Node) throws -> Def.Topic {
                let mapping = try yaml.checkMapping(context: "custom_defs.topics[]")
                let parser = OptsParser()
                parser.addOpts(from: self)
                try parser.apply(mapping: mapping)

                guard let name = nameOpt.value else {
                    throw OptionsError(.localized(.errCfgCustomDefTopicName, try yaml.asDebugString()))
                }
                return Def.Topic(topic: Topic(title: name,
                                              overview: abstractOpt.value),
                                 children: childrenOpt.value)
            }

            /// Try to parse a list of `Group.Topic`s out of the yaml
            static func topics(yaml: Yams.Node) throws -> [Def.Topic] {
                try yaml.checkSequence(context: "custom_defs.topics").map { topicYaml in
                    try TopicParser().topic(yaml: topicYaml)
                }
            }
        }
    }
}

// MARK: Custom Def Builder

extension GroupCustom.Def {
    /// Pull out the contents of an item that match the yaml record.
    ///
    /// XXX indexify the defchildren, need to understand name dups
    func apply(to defItem: DefItem) -> [Item] {
        let items = topics.flatMap { topic in
            topic.children.compactMap { name -> Item? in
                guard let index = defItem.defChildren.firstIndex(where: { name == $0.name || name == $0.primaryNamePieces.flattened }) else {
                    logWarning("Can't resolve def_item child name \(name) inside \(defItem.name)")
                    return nil
                }
                let item = defItem.children.remove(at: index)
                item.topic = topic.topic
                return item
            }
        }
        if skipUnlisted {
            defItem.children = []
        }
        return items
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

extension GroupCustom.Def: CustomStringConvertible {
    var description: String {
        "Def name=\(name) skipUnlisted=\(skipUnlisted) topics=\(topics)"
    }
}

extension GroupCustom.Def.Topic: CustomStringConvertible {
    var description: String {
        var line = "Tpc \(topic)"
        if !children.isEmpty {
            line += " children=\(children)"
        }
        return line
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
