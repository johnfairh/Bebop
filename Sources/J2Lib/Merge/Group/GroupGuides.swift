//
//  GroupGuides.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

final class GroupGuides: Configurable {
    let docsOpt = GlobListOpt(l: "documentation").help("GLOB1,GLOB2,...")

    init(config: Config) {
        config.register(self)
    }

    /// Go discover and load up the guides
    /// Throws only if something bad happens re. filesystem access.
    func discoverGuides() throws -> [GuideItem] {
        var guides = [String: Localized<Markdown>]()
        try docsOpt.value.forEach { globPattern in
            logDebug("Group: Searching for guides using '\(globPattern)'")
            var count = 0
            try Glob.files(globPattern).forEach { url in
                let filename = url.lastPathComponent
                guard filename.lowercased().hasSuffix(".md") else {
                    logDebug("Group: Ignoring \(url.path), wrong suffix.")
                    return
                }
                guard guides[filename] == nil else {
                    logWarning("Duplicate guide name '\(filename)', ignoring '\(url.path)'.")
                    return
                }
                guides[filename] = try Localized<Markdown>(localizingFile: url)
                count += 1
            }
            if count == 0 {
                logWarning("No files matching '*.md' found expanding '\(globPattern)'.")
            } else {
                logDebug("Group: Found \(count) guides.")
            }
        }
        let uniquer = StringUniquer()
        return guides.map { kv in
            let fileBasename = String(kv.key.dropLast(3 /*.md*/))
            let slug = uniquer.unique(fileBasename.slugged)
            let title = Localized<String>(unLocalized: fileBasename)
            return GuideItem(name: kv.key, slug: slug, title: title, content: kv.value)
        }.sorted { $0.name > $1.name }
    }
}
