//
//  GroupCustom.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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

    func checkOptions() throws {
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
                    logWarning(.wrnCustomDefDup, def.name)
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
        let mixLanguages: Bool
        let topics: [Topic]

        struct Topic: Equatable {
            let topic: BebopLib.Topic
            let children: [Item]
        }

        enum Item: Equatable {
            case name(String)
            case pattern(String)
            case group(Group)
        }
    }

    /// The data structure parsed out of the custom_defs yaml is an array of these
    struct Def: Equatable {
        let name: String
        let skipUnlisted: Bool
        let topics: [Topic]

        struct Topic: Equatable {
            let topic: BebopLib.Topic
            let children: [String]
        }
    }

    // MARK: Index

    /// A name-indexed lookup of all the Items used to populate the custom group tree
    final class Index {
        private var nameMap = [String: (Item, Int)]()
        private var moduleNameMap = [String: Item]()

        init(items: [Item]) {
            items.enumerated().forEach { add(item: $0.1, sortIndex: $0.0) }
        }

        /// Store qualified names of defs too so we can handle ModuleA.Foo and ModuleB.Foo.
        private func add(item: Item, sortIndex: Int) {
            nameMap[item.name] = (item, sortIndex)
            if let defItem = item as? DefItem {
                moduleNameMap[defItem.nameInModule] = item
            }
        }

        /// Remove items from our caches as they are used - no dups
        func find(name: String) -> Item? {
            // Order important, modules first: A.B defaults to A-is-module
            guard let item = moduleNameMap[name] ?? nameMap[name]?.0 else {
                return nil
            }
            nameMap.removeValue(forKey: item.name)
            if let defItem = item as? DefItem {
                moduleNameMap.removeValue(forKey: defItem.nameInModule)
            }
            return item
        }

        /// Remove all items from our caches that match a regular expression pattern
        func findAll(matching pattern: String) -> [Item] {
            var items = [Item]()

            func search<K>(dict: [String:K]) {
                let matchingKeys = dict.keys.filter { $0.re_isMatch(pattern) }
                matchingKeys.forEach { key in
                    find(name: key).flatMap { items.append($0) }
                }
            }
            // Order important, match a module name first
            search(dict: moduleNameMap)
            search(dict: nameMap)

            return items
        }

        /// What's left are processed by the 'group-by-kind' path -- must preserve original sort order!
        var remainingItems: [Item] {
            Array(nameMap.values.sorted(by: { $0.1 < $1.1 }).map { $0.0 })
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
            GroupItem(kind: .custom(group.name, group.mixLanguages),
                      abstract: group.abstract,
                      contents: build(topics: group.topics),
                      uniquer: uniquer)
        }

        func build(topics: [Group.Topic]) -> [Item] {
            topics.flatMap { topic -> [Item] in
                let items = topic.children.flatMap { build(item: $0) }
                items.forEach { $0.topic = topic.topic }
                return items
            }
        }

        func build(item: Group.Item) -> [Item] {
            switch item {
            case .name(let name):
                guard let theItem = index.find(name: name) else {
                    logWarning(.wrnCustomGrpMissing, name)
                    return []
                }
                return [theItem]

            case .pattern(let pattern):
                let items = index.findAll(matching: pattern)
                guard !items.isEmpty else {
                    logWarning(.wrnUnmatchedGrpRegex, pattern)
                    return []
                }
                return items.sorted(by: { $0.sortableName < $1.sortableName })

            case .group(let group):
                return [build(group: group)]
            }
        }
    }

    // MARK: Groups Parser

    /// Recursive yaml parser for custom groups & topics structure
    private struct GroupParser {
        let nameOpt = LocStringOpt(y: "name")
        let abstractOpt = LocStringOpt(y: "abstract")
        let mixLanguagesOpt = BoolOpt(y: "mix_languages").def(true)
        let childrenOpt = YamlOpt(y: "children")
        let topicsOpt = YamlOpt(y: "topics")

        private func parse(yaml: Yams.Node, context: String) throws {
            let mapping = try yaml.checkMapping(context: context)
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            // common error checks
            if !nameOpt.configured {
                throw BBError(.errCfgCustomGrpName, try yaml.asDebugString())
            }
            if childrenOpt.configured && topicsOpt.configured {
                throw BBError(.errCfgCustomGrpBoth, try yaml.asDebugString())
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
            Stats.inc(.groupCustomDecoded)
            return Group(name: nameOpt.value!,
                         abstract: abstractOpt.value,
                         mixLanguages: mixLanguagesOpt.value,
                         topics: topics)
        }

        /// Try to parse a `Group.Topic` out of the yaml
        func topic(yaml: Yams.Node, context: String) throws -> Group.Topic {
            try parse(yaml: yaml, context: context)
            if topicsOpt.configured {
                throw BBError(.errCfgCustomGrpNested, try yaml.asDebugString())
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
                if let childScalar = childYaml.scalar, case let string = childScalar.decodedString {
                    guard let matches = string.re_match(#"^/(.*)/$"#) else {
                        return .name(string)
                    }
                    let pattern = matches[1]
                    try pattern.re_check()
                    return .pattern(pattern)
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
                throw BBError(.errCfgCustomDefName, try yaml.asDebugString())
            }
            guard let topicsYaml = topicsOpt.value else {
                throw BBError(.errCfgCustomDefTopics, try yaml.asDebugString())
            }
            Stats.inc(.groupCustomDefDecoded)
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
                    throw BBError(.errCfgCustomDefTopicName, try yaml.asDebugString())
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

// I'm too dumb to figure out how to index this properly.
//
// We've got an ordered def list, and an ordered name list.
// We need to pull the named defs out of their list, leaving
// the rest in order.  The implementation here is O(N.M) but the
// sizes are pretty small.  Need something like a linked list for
// order augmented with a keyed lookup index.

private extension DefItemList {
    mutating func removeFirst(where filter: (DefItem) -> Bool) -> DefItem? {
        var result: DefItem? = nil
        var new = [DefItem]()
        for (i, el) in self.enumerated() {
            if filter(el) {
                result = el
                new += self[index(after: i)..<endIndex]
                break
            } else {
                new.append(el)
            }
        }
        self = new
        return result
    }

    mutating func customDefMatch(name: String) -> DefItem? {
        removeFirst { item in
            var names = [item.name, item.primaryNamePieces.flattened]
            if let constraint = item.extensionConstraint {
                names = names.map { "\($0) \(constraint.text)" }
            }
            return names.contains(name)
        }
    }
}

extension GroupCustom.Def {
    /// Pull out the contents of an item that match the yaml record.
    func apply(to defItem: DefItem) -> [Item] {
        var defChildren = defItem.defChildren

        let items = topics.flatMap { topic in
            topic.children.compactMap { name -> Item? in
                guard let item = defChildren.customDefMatch(name: name) else {
                    logWarning(.wrnCustomDefMissing, name, defItem.name)
                    return nil
                }
                item.topic = topic.topic
                return item
            }
        }
        if skipUnlisted {
            defChildren = []
        }
        defItem.children = defChildren
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
            line += " topics=\(topics)"
        }
        return line
    }
}

extension GroupCustom.Group.Topic: CustomStringConvertible {
    var description: String {
        var line = "Tpc \(topic)"
        if !children.isEmpty {
            line += " children=\(children)"
        }
        return line
    }
}

extension GroupCustom.Group.Item: CustomStringConvertible {
    var description: String {
        switch self {
        case .name(let str): return str
        case .group(let grp): return grp.description
        case .pattern(let pat): return "/\(pat)/"
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
