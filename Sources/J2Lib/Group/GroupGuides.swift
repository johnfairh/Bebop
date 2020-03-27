//
//  GroupGuides.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Yams

/// Guides - discovery, item creation, custom titles
///
final class GroupGuides: Configurable {
    let guidesOpt = GlobListOpt(l: "guides").help("FILEPATHGLOB1,FILEPATHGLOB2,...")
    let guideTitlesOpt = YamlOpt(y: "guide_titles")

    let documentationAliasOpt: AliasOpt

    typealias Titles = [String : Localized<String>]
    private(set) var titles = Titles()

    init(config: Config) {
        documentationAliasOpt = AliasOpt(realOpt: guidesOpt, l: "documentation")
        config.register(self)
    }

    // MARK: Custom titles

    struct GuideTitleParser {
        let nameOpt = StringOpt(y: "name")
        let titleOpt = LocStringOpt(y: "title")

        private func parse(yaml: Yams.Node, titles: inout Titles) throws {
            let mapping = try yaml.checkMapping(context: "guide_titles[]")
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            guard let name = nameOpt.value,
                let title = titleOpt.value else {
                    throw OptionsError(.localized(.errCfgGuideTitleFields, try yaml.asDebugString()))
            }

            if titles[name] == nil {
                titles[name] = title
            } else {
                logWarning(.localized(.wrnGuideTitleDup, name))
            }
        }

        static func titles(yaml: Yams.Node) throws -> Titles {
            var titles = Titles()
            let sequence = try yaml.checkSequence(context: "guide_titles")
            try sequence.forEach { sequenceNode in
                try GuideTitleParser().parse(yaml: sequenceNode, titles: &titles)
            }
            return titles
        }
    }

    func checkOptions(published: Config.Published) throws {
        if let titlesYaml = guideTitlesOpt.value {
            logDebug("Guide: start parsing guide_titles")
            titles = try GuideTitleParser.titles(yaml: titlesYaml)
            logDebug("Guide: end parsing guide_titles: \(titles)")
        }
    }

    // MARK: Guide creation

    /// Go discover and load up the guides
    /// Throws only if something bad happens re. filesystem access.
    func discoverGuides() throws -> [GuideItem] {
        let guides = try guidesOpt.value.readLocalizedMarkdownFiles()
        let uniquer = StringUniquer()
        let guideItems = guides.map { kv -> GuideItem in
            let slug = uniquer.unique(kv.key.slugged)
            let title = titles.removeValue(forKey: kv.key) ?? Localized<String>(unlocalized: kv.key)
            return GuideItem(name: kv.key, slug: slug, title: title, content: kv.value)
        }.sorted { $0.name < $1.name }
        if !titles.isEmpty {
            logWarning(.localized(.wrnGuideTitleUnused, titles.keys))
        }
        return guideItems
    }
}
