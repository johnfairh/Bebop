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
    let customGroupsOpt = YamlOpt(y: "custom_groups")

    let customCategoriesAlias: AliasOpt

    private(set) var groups = [Group]()

    init(config: Config) {
        customCategoriesAlias = AliasOpt(realOpt: customGroupsOpt, l: "custom-categories")
        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        if let customGroupsYaml = customGroupsOpt.value {
            logDebug("Group: start parsing custom_groups")
            groups = try Parser.groups(yaml: customGroupsYaml)
            logDebug("Group: done parsing custom_groups")
        }
    }

    /// The data structure parsed out of the custom_groups yaml is an array of these
    struct Group {
        let name: Localized<String>
        let abstract: Localized<String>?
        let children: Children?

        enum Children {
            case items([Item])
            case topics([Topic], Bool)
        }

        enum Item {
            case name(String)
            case group(Group)
        }

        struct Topic {
            let name: Localized<String>
            let abstract: Localized<String>?
            let children: [Item]
        }
    }

    // MARK: Parser

    /// Recursive yaml parser for custom groups & topics structure
    struct Parser {
        let nameOpt = LocStringOpt(y: "name")
        let abstractOpt = LocStringOpt(y: "abstract")
        let childrenOpt = YamlOpt(y: "children")
        let topicsOpt = YamlOpt(y: "topics")
        let skipUnlistedOpt = BoolOpt(y: "skip_unlisted")

        private func parse(yaml: Node.Mapping) throws {
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: yaml)

            // common error checks
            if !nameOpt.configured {
                throw OptionsError("Missing 'name' in custom group/topic: \(yaml)")
            }
            if childrenOpt.configured && topicsOpt.configured {
                throw OptionsError("Can't set both 'children' and 'topics' in custom group: \(yaml)")
            }
            if skipUnlistedOpt.value && !topicsOpt.configured {
                throw OptionsError("'skip_unlisted' requires 'topics' in custom group: \(yaml)")
            }
        }

        /// Try to parse one `Group` out of the mapping
        func group(yaml: Node.Mapping) throws -> Group {
            try parse(yaml: yaml)
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
        func topic(yaml: Node.Mapping) throws -> Group.Topic {
            try parse(yaml: yaml)
            if topicsOpt.configured {
                throw OptionsError("Found nested 'topics' in custom group: \(yaml)")
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
                let childMapping = try childYaml.checkMapping(context: "topics.children[n]")
                return .group(try Parser().group(yaml: childMapping))
            }
        }

        // MARK: Factory

        /// Try to parse a list of `Group`s out of the yaml
        static func groups(yaml: Yams.Node) throws -> [Group] {
            let groupsSequence = try yaml.checkSequence(context: "custom_groups")
            return try groupsSequence.map { yaml in
                let groupMapping = try yaml.checkMapping(context: "custom_groups[]")
                return try Parser().group(yaml: groupMapping)
            }
        }

        /// Try to parse a list of `Group.Topic`s out of the yaml
        static func topics(yaml: Yams.Node) throws -> [Group.Topic] {
            let topicsSequence = try yaml.checkSequence(context: "topics")
            return try topicsSequence.map { topicYaml in
                let topicMapping = try topicYaml.checkMapping(context: "topics[]")
                return try Parser().topic(yaml: topicMapping)
            }
        }
    }
}
