//
//  Format.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

public final class Format: Configurable {
    let readmeOpt = PathOpt(l: "readme").help("FILEPATH")

    private var configPublished: Config.Published

    public init(config: Config) {
        configPublished = config.published
        config.register(self)
    }

    public func checkOptions(published: Config.Published) throws {
        try readmeOpt.checkIsFile()
    }

    public func format(items: [Item]) throws -> [Item] {
        let allItems = items + [try createReadme()]
        URLVisitor().walk(items: allItems)
        MarkdownVisitor().walk(items: allItems)
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
        return ReadmeItem(content: Localized<Markdown>(unlocalized: Markdown("Read ... me?")))
    }
}


struct MarkdownVisitor: ItemVisitor {
    /// Format the def's markdown.
    /// This both generates HTML versions of everything and also replaces the original markdown
    /// with an auto-linked version.
    func visit(defItem: DefItem, parents: [Item]) {
        defItem.documentation.format { render(md: $0) }

        // XXX deprecation notice
    }

    // 1 - build markdown AST
    // 2 - autolink pass, walk for `code` nodes and wrap in link
    // 3 - roundtrip to markdown and replace original
    // 4 - fixup pass
    //     a) replace headings with custom nodes adding styles and tags
    //     b) create scaffolding around callouts
    //     c) ??? code blocks styles - at least language rewrite for prism
    //     d) math reformatting
    // 5 - render that as html
    func render(md: Markdown) -> (Markdown, Html) {
        guard let doc = CMDocument(markdown: md),
            let html = try? doc.renderHtml() else {
            logDebug("Couldn't parse and render markdown '\(md)'.")
            return (md, Html(""))
        }

        return (md, Html(html))
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
    }
}
