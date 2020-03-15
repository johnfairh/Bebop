//
//  GroupGuides.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

final class GroupGuides: Configurable {
    let guidesOpt = GlobListOpt(l: "guides").help("FILEPATHGLOB1,FILEPATHGLOB2,...")

    let documentationAliasOpt: AliasOpt

    init(config: Config) {
        documentationAliasOpt = AliasOpt(realOpt: guidesOpt, l: "documentation")
        config.register(self)
    }

    /// Go discover and load up the guides
    /// Throws only if something bad happens re. filesystem access.
    func discoverGuides() throws -> [GuideItem] {
        let guides = try guidesOpt.value.readLocalizedMarkdownFiles()
        let uniquer = StringUniquer()
        return guides.map { kv in
            let slug = uniquer.unique(kv.key.slugged)
            let title = Localized<String>(unlocalized: kv.key)
            return GuideItem(name: kv.key, slug: slug, title: title, content: kv.value)
        }.sorted { $0.name < $1.name }
    }
}
