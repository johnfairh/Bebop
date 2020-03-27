//
//  FormatMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

final class MarkdownFormatter: ItemVisitorProtocol {
    /// What (programming) language to use if the user doesn't specify and there's no way to guess.
    let fallbackLanguage: DefLanguage
    /// Current opinion about code language
    var currentLanguage: DefLanguage?
    /// Language to use if user doesn't specify
    var defaultLanguage: DefLanguage {
        currentLanguage ?? fallbackLanguage
    }

    /// For uniquing heading links
    let uniquer: StringUniquer

    /// For resolving autolinks
    let autolink: FormatAutolink?

    /// Context while visiting...
    var visitItemNameContext: Item! = nil
    var visitItemLinkContext: Item! = nil

    init(language: DefLanguage, autolink: FormatAutolink? = nil) {
        fallbackLanguage = language
        uniquer = StringUniquer()
        self.autolink = autolink
    }

    /// Format the def's markdown.
    /// This both generates HTML versions of everything and also replaces the original markdown
    /// with an auto-linked version for generating markdown output.
    private func format(item: Item) {
        let formatters = RichText.Formatters(inline: { self.formatInline(md: $0)},
                                             block: { self.format(md: $0) })
        visitItemNameContext = item
        visitItemLinkContext = item
        item.format(formatters: formatters)

        if let topic = item.topic {
            visitItemLinkContext = item.parent ?? item
            topic.format(formatters: formatters)
        }

        visitItemNameContext = nil
        visitItemLinkContext = nil
    }

    func visit(defItem: DefItem, parents: [Item]) {
        uniquer.reset() // this isn't right because of all the other stuff on the page.
        currentLanguage = defItem.primaryLanguage
        defItem.finalizeDeclNotes()
        format(item: defItem)
        currentLanguage = nil
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        uniquer.reset()
        format(item: groupItem)
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        uniquer.reset()
        format(item: guideItem)
    }

    /// 1 - build markdown AST
    /// 2 - autolink pass, walk for `code` nodes and wrap in link
    /// 3 - roundtrip to markdown and replace original
    /// 4 - fixup pass for html rendering
    /// 5 - render that as html
    func format(md: Markdown) -> (Markdown, Html) {
        guard let doc = CMDocument(markdown: md) else {
            logDebug("Couldn't parse and render markdown '\(md)'.")
            return (md, Html(""))
        }

        autolink(doc: doc)

        let mdOut = doc.node.renderMarkdown()

        customizeForHtml(doc: doc)

        let html = doc.node.renderHtml()

        Stats.inc(.formatMarkdown)

        return (mdOut, html)
    }

    /// Render for some inline html, stripping the outer paragraph element.
    func formatInline(md: Markdown) -> (Markdown, Html) {
        let (md, html) = format(md: md)
        let inlineHtml = html.html.re_sub("^<p>|</p>$", with: "")
        return (md, Html(inlineHtml))
    }

    /// 2 - autolink pass
    ///   spot `code` sections that resolve to identifiers and wrap in links.
    func autolink(doc: CMDocument) {
        let iterator = CMIterator(doc: doc)

        try! iterator.forEach { node, iter in
            guard node.type == .code else {
                return
            }

            guard let autolink = autolink?.link(for: node.literal!,
                                                nameContext: visitItemNameContext,
                                                linkContext: visitItemLinkContext) else {
                return
            }
            let linkNode = CMNode.init(type: .link)
            try! linkNode.setLinkURL(URL(string: autolink.markdownURL)!)
            try! linkNode.insertIntoTree(afterNode: node)
            try! node.insertIntoTree(asFirstChildOf: linkNode)
            linkNode.setUserData(retained: autolink)
            iter.reset(to: linkNode, eventType: .exit)
        }
    }

    /// 4 - fixup pass for html rendering:
    ///     a) replace headings with custom nodes adding styles and tags
    ///     b) create scaffolding around callouts
    ///     c) code blocks language rewrite for prism / default
    ///     d) autolinked links to split-language html links
    ///     e) math reformatting [one day]
    ///
    /// All the !s and try!s here are to do with poorly-wrapped cmark interfaces that
    /// are (not) policing node types.
    func customizeForHtml(doc: CMDocument) {
        let iterator = CMIterator(doc: doc)

        try! iterator.forEach { node, iter in
            switch node.type {
            case .heading:
                customizeHeading(heading: node, iterator: iter)

            case .codeBlock:
                customizeCodeBlock(block: node, iterator: iter)

            case .list:
                if node.maybeCalloutList {
                    customizeCallouts(listNode: node, iterator: iter)
                }

            case .link:
                if let autolink = node.getUserDataRetained(kind: Autolink.self) {
                    customizeAutolink(link: node, autolink: autolink, iterator: iter)
                }

            default:
                break
            }
        }
    }

    /// Replace headings with more complicated HTML to make the anchors.js stuff work
    /// with the fixed heading.  (Headings are container elements, can have multiple children
    /// if there is eg. linking/italics in the heading.)
    func customizeHeading(heading: CMNode, iterator: Iterator) {
        let anchorId = uniquer.unique(heading.renderPlainText().slugged)
        let level = heading.headingLevel
        let replacementNode =
            CMNode(customEnter:
                    #"""
                    <h\#(level) class="j2-anchor j2-heading" id="\#(anchorId)">
                    <span data-anchor-id="\#(anchorId)">
                    """#,
                customExit: "</span></h\(level)>")

        replacementNode.replaceInTree(node: heading)
        iterator.reset(to: replacementNode, eventType: .enter)
    }

    /// Make sure the language attribute on fenced code blocks ("```" sections)
    /// (oh ffs xcode calm down :() is set to something useful that
    /// Prism.js will understand.
    func customizeCodeBlock(block: CMNode, iterator: Iterator) {
        if let language = block.fencedCodeInfo,
            !language.isEmpty {
            // Accommodate Rouge spellings.  Miss you Rouge.
            if ["objc", "obj-c", "obj_c"].contains(language) {
                try! block.setFencedCodeInfo("objectivec")
            }
        } else {
            try! block.setFencedCodeInfo(defaultLanguage.prismLanguage)
        }
    }

    /// Create special callout markup for anything that looks like a callout --- we're past
    /// parameters etc. by now, all that's left are warnings/notes/etc.
    ///
    /// Strip out any leftover localization key callouts now - processed back in Gather.
    func customizeCallouts(listNode: CMNode, iterator: Iterator) {
        var iteratorReset = false

        listNode.forEachCallout { listItem, text, callout in
            guard callout.isNormalCallout else {
                return
            }

            guard !callout.isLocalizationKey else {
                listItem.unlink()
                if !iteratorReset && listNode.firstChild == nil {
                    iteratorReset = true
                    iterator.reset(to: listNode, eventType: .exit)
                }
                return
            }

            let calloutNode =
                CMNode(customEnter:
                    #"""
                    <div class="j2-callout j2-callout-\#(callout.title.slugged)">
                    <div class="j2-callout-title" role="heading" aria-level="6">\#(callout.title)</div>
                    """#,
                    customExit: "</div>")

            // Position before the entire list, take the listitem's content
            try! calloutNode.insertIntoTree(beforeNode: listNode)
            text.removeCalloutTitle(callout) // drop the "- warning:" prefix
            calloutNode.moveChildren(from: listItem)
            listItem.unlink()
            // Still have to traverse the callout[s]' content - and the
            // list node may vanish out from under us if all it contained
            // was callouts.
            if !iteratorReset {
                iteratorReset = true
                iterator.reset(to: calloutNode, eventType: .enter)
            }
        }
    }

    /// Called for links that refer to defs in our docs.  Replace the markdown link with some html to support
    /// swift/objc switchable name links.
    func customizeAutolink(link: CMNode, autolink: Autolink, iterator: Iterator) {
        let htmlNode = CMNode(type: .htmlInline)
        try! htmlNode.setLiteral(autolink.html)
        try! htmlNode.insertIntoTree(beforeNode: link)
        link.unlink()
        iterator.reset(to: htmlNode, eventType: .exit)
    }
}

extension DefLanguage {
    /// Name of language according to Prism, the code highlighter
    var prismLanguage: String {
        switch self {
        case .swift: return "swift"
        case .objc: return "objectivec"
        }
    }
}
