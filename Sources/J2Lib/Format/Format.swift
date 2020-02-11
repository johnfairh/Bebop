//
//  Format.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

public struct Format: Configurable {
    public init(config: Config) {
        config.register(self)
    }

    public func format(items: [Item]) throws -> [Item] {
        URLVisitor().walk(items: items)
        MarkdownVisitor().walk(items: items)
        return items
    }
}


struct MarkdownVisitor: ItemVisitor {
    /// Format the def's markdown.
    /// This both generates HTML versions of everything and also replaces the original markdown
    /// with an auto-linked version.
    func visit(defItem: DefItem, parents: [Item]) {
        let rendered = defItem.markdownDocs.mapValues { render(docs: $0) }
        defItem.markdownDocs = rendered.mapValues { $0.0 }
        defItem.htmlDocs = rendered.mapValues { $0.1 }

        // XXX deprecation notice
    }

    /// This isn't *too* bad but wow....
    func render(docs: DefMarkdownDocs) -> (DefMarkdownDocs, DefHtmlDocs) {
        let abstracts = docs.abstract.flatMap { render(md: $0) } ?? (nil, nil)
        let overviews = docs.overview.flatMap { render(md: $0) } ?? (nil, nil)
        let returns   = docs.returns.flatMap { render(md: $0) } ?? (nil, nil)
        let params    = docs.parameters.mapValues { render(md: $0) }

        let md = DefMarkdownDocs(abstract: abstracts.0,
                                 overview: overviews.0,
                                 returns: returns.0,
                                 parameters: params.mapValues { $0.0 })

        let html = DefHtmlDocs(abstract: abstracts.1,
                               overview: overviews.1,
                               returns: returns.1,
                               parameters: params.mapValues { $0.1 })

        return (md, html)
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
}
