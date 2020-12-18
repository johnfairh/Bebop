//
//  Format.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

public final class Format: Configurable {
    let readmeOpt = PathOpt(l: "readme").help("FILEPATH")

    let autolink: FormatAutolink
    let abstract: FormatAbstracts
    let linkRewriter: FormatLinkRewriter

    private let published: Published

    public init(config: Config) {
        autolink = FormatAutolink(config: config)
        abstract = FormatAbstracts(config: config)
        linkRewriter = FormatLinkRewriter(config: config)
        published = config.published
        config.register(self)
    }

    func checkOptions() throws {
        try readmeOpt.checkIsFile()
    }

    public func format(items: [Item]) throws -> [Item] {
        let readme = try createReadme()
        let allItems = items + [readme]
        logDebug("Format: Assigning URLs")
        try URLFormatter(childItemStyle: published.childItemStyle,
                     multiModule: published.isMultiModule).walk(items: allItems)
        let linearVisitor = LinearItemVisitor()
        try linearVisitor.walk(items: allItems)
        readme.linearNext = items.first
        readme.linearPrev = linearVisitor.visited
        logDebug("Format: Attach custom abstracts")
        try abstract.attach(items: allItems)
        logDebug("Format: Building autolink index")
        autolink.populate(defs: allItems)
        logDebug("Format: Formatting declarations")
        try DeclarationFormatter(autolink: autolink).walk(items: allItems)
        logDebug("Format: Generating HTML")
        let mdFormatter = MarkdownFormatter(language: published.defaultLanguage,
                                            autolink: autolink,
                                            linkRewriter: linkRewriter)
        try mdFormatter.walk(items: allItems)
        if mdFormatter.hasMath {
            published.setUsesMath()
        }
        return allItems
    }

    static let primaryReadmeName = "README.md"

    /// Go discover the readme.
    func createReadme() throws -> ReadmeItem {
        if let readmeURL = readmeOpt.value {
            logDebug("Format: Using configured readme '\(readmeURL.path)'")
            return ReadmeItem(content: try Localized<Markdown>(localizingFile: readmeURL))
        }

        let srcDirURL = published.someSourceDirectoryURL ?? FileManager.default.currentDirectory
        for guess in [Format.primaryReadmeName, "README.markdown", "README.mdown", "README"] {
            let guessURL = srcDirURL.appendingPathComponent(guess)
            if FileManager.default.fileExists(atPath: guessURL.path) {
                logDebug("Format: Using found readme '\(guessURL.path)'.")
                return ReadmeItem(content: try Localized<Markdown>(localizingFile: guessURL))
            }
        }
        logDebug("Format: Can't find anything that looks like a readme, making something up.")
        let readmeModule = published.moduleNames.first ?? "Module"
        var readmeMd = Localized<String>(unlocalized: "# \(readmeModule)")
        if let readmeAuthor = published.authorName {
            readmeMd = readmeMd
                + "\n### "
                + .localizedOutput(.authors)
                + "\n\n"
                + readmeAuthor
        }
        return ReadmeItem(content: readmeMd.mapValues { Markdown($0) })
    }
}

extension Published {
    var someSourceDirectoryURL: URL? {
        modules.first(where: { $0.sourceDirectory != nil })?.sourceDirectory
    }
}

/// Pass to assign the 'linear' total order for next/prev navigation
fileprivate final class LinearItemVisitor: ItemVisitorProtocol {
    var visited: Item?
    func visit(item: Item) {
        if item.renderAsPage {
            if let visited = visited {
                visited.linearNext = item
                item.linearPrev = visited
            }
            visited = item
        }
    }
    func visit(defItem: DefItem, parents: [Item]) { visit(item: defItem) }
    func visit(groupItem: GroupItem, parents: [Item]) { visit(item: groupItem) }
    func visit(guideItem: GuideItem, parents: [Item]) { visit(item: guideItem) }
    func visit(readmeItem: ReadmeItem, parents: [Item]) {}
}
