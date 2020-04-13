//
//  Format.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Format: Configurable {
    let readmeOpt = PathOpt(l: "readme").help("FILEPATH")

    let autolink: FormatAutolink
    let abstract: FormatAbstracts
    let linkRewriter: FormatLinkRewriter

    private let configPublished: Config.Published

    public init(config: Config) {
        autolink = FormatAutolink(config: config)
        abstract = FormatAbstracts(config: config)
        linkRewriter = FormatLinkRewriter(config: config)
        configPublished = config.published
        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        try readmeOpt.checkIsFile()
    }

    public func format(items: [Item]) throws -> [Item] {
        let readme = try createReadme()
        setLinearlinks(readme: readme, to: items)
        let allItems = items + [readme]
        logDebug("Format: Assigning URLs")
        URLFormatter(childItemStyle: configPublished.childItemStyle,
                     multiModule: configPublished.isMultiModule).walk(items: allItems)
        logDebug("Format: Attach custom abstracts")
        try abstract.attach(items: allItems)
        logDebug("Format: Building autolink index")
        autolink.populate(defs: allItems)
        logDebug("Format: Formatting declarations")
        DeclarationFormatter(autolink: autolink).walk(items: allItems)
        logDebug("Format: Generating HTML")
        MarkdownFormatter(language: configPublished.defaultLanguage,
                          autolink: autolink,
                          linkRewriter: linkRewriter).walk(items: allItems)
        return allItems
    }

    /// Go discover the readme.
    func createReadme() throws -> ReadmeItem {
        if let readmeURL = readmeOpt.value {
            logDebug("Format: Using configured readme '\(readmeURL.path)'")
            return ReadmeItem(content: try Localized<Markdown>(localizingFile: readmeURL))
        }

        let srcDirURL = configPublished.sourceDirectoryURL ?? FileManager.default.currentDirectory
        for guess in ["README.md", "README.markdown", "README.mdown", "README"] {
            let guessURL = srcDirURL.appendingPathComponent(guess)
            if FileManager.default.fileExists(atPath: guessURL.path) {
                logDebug("Format: Using found readme '\(guessURL.path)'.")
                return ReadmeItem(content: try Localized<Markdown>(localizingFile: guessURL))
            }
        }
        logDebug("Format: Can't find anything that looks like a readme, making something up.")
        let readmeModule = configPublished.moduleNames.first ?? "Module"
        var readmeMd = Localized<String>(unlocalized: "# \(readmeModule)")
        if let readmeAuthor = configPublished.authorName {
            readmeMd = readmeMd
                + "\n### "
                + .localizedOutput(.authors)
                + "\n\n"
                + readmeAuthor
        }
        return ReadmeItem(content: readmeMd.mapValues { Markdown($0) })
    }

    /// Add the readme into the total order - but no links pointing back to it, naming is tricky
    /// so we do it in mustache.
    private func setLinearlinks(readme: Item, to items: [Item]) {
        if let first = items.first {
            readme.linearNext = first
            var last = items.last!
            while let nextLast = last.children.last {
                last = nextLast
            }
            readme.linearPrev = last
        }
    }
}
