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
/// Not sure what happens next tbh.
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
            groups = try Parser.groups(yaml: customGroupsYaml)
            logDebug("Group: done parsing custom_groups: \(groups)")
        }
    }

    /// The data structure parsed out of the custom_groups yaml is an array of these
    struct Group: Equatable {
        let name: Localized<String>
        let abstract: Localized<String>?
        let children: Children?

        enum Children: Equatable {
            case items([Item])
            case topics([Topic], Bool)
        }

        enum Item: Equatable {
            case name(String)
            case group(Group)
        }

        struct Topic: Equatable {
            let name: Localized<String>
            let abstract: Localized<String>?
            let children: [Item]
        }
    }

    // MARK: Parser

    /// Recursive yaml parser for custom groups & topics structure
    private struct Parser {
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
            if skipUnlistedOpt.value && !topicsOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpUnlisted, try yaml.asDebugString()))
            }
        }

        /// Try to parse one `Group` out of the mapping
        func group(yaml: Yams.Node, context: String) throws -> Group {
            try parse(yaml: yaml, context: context)
            if childrenOpt.configured {
                return Group(name: nameOpt.value!,
                             abstract: abstractOpt.value,
                             children: .items(try items()))
            }
            if let topicsYaml = topicsOpt.value {
                let topics = try Parser.topics(yaml: topicsYaml)
                return Group(name: nameOpt.value!,
                             abstract: abstractOpt.value,
                             children: .topics(topics, skipUnlistedOpt.value))
            }
            return Group(name: nameOpt.value!, abstract: abstractOpt.value, children: nil)
        }

        /// Try to parse a `Group.Topic` out of the yaml
        func topic(yaml: Yams.Node, context: String) throws -> Group.Topic {
            try parse(yaml: yaml, context: context)
            if topicsOpt.configured {
                throw OptionsError(.localized(.errCfgCustomGrpNested, try yaml.asDebugString()))
            }
            return Group.Topic(name: nameOpt.value!,
                               abstract: abstractOpt.value,
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
                return .group(try Parser().group(yaml: childYaml, context: "topics.children[n]"))
            }
        }

        // MARK: Factory

        /// Try to parse a list of `Group`s out of the yaml
        static func groups(yaml: Yams.Node) throws -> [Group] {
            try yaml.checkSequence(context: "custom_groups").map { groupYaml in
                try Parser().group(yaml: groupYaml, context: "custom_groups[]")
            }
        }

        /// Try to parse a list of `Group.Topic`s out of the yaml
        static func topics(yaml: Yams.Node) throws -> [Group.Topic] {
            try yaml.checkSequence(context: "topics").map { topicYaml in
                try Parser().topic(yaml: topicYaml, context: "topics[]")
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
        if let children = children {
            line += " children=[\(children)]"
        }
        return line
    }
}

extension GroupCustom.Group.Children: CustomStringConvertible {
    var description: String {
        switch self {
        case .items(let items):
            return "items\(items)"
        case .topics(let topics, let flag):
            return "iopics(\(flag), [\(topics)])"
        }
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

extension GroupCustom.Group.Topic: CustomStringConvertible {
    var description: String {
        var line = "Tpc name=\(name.first!.value)"
        if let abstract = abstract {
            line += " abstract=\(abstract.first!.value)"
        }
        if !children.isEmpty {
            line += " children=[\(children)]"
        }
        return line
    }
}
