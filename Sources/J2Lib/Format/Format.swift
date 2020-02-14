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
        MarkdownVisitor(language: .swift).walk(items: allItems) // XXX from --objc -type option ?
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

enum DefLanguage: String {
    case swift = "swift"
    case objc = "objectivec"
}

final class MarkdownVisitor: ItemVisitorProtocol {
    /// What (programming) language to use if the user doesn't specify and there's no way to guess.
    let fallbackCodeLanguage: DefLanguage
    /// Current opinion about code language
    var currentCodeLanguage: DefLanguage?

    var defaultCodeLanguage: DefLanguage {
        currentCodeLanguage ?? fallbackCodeLanguage
    }

    init(language: DefLanguage) {
        fallbackCodeLanguage = language
        currentCodeLanguage = nil
    }

    /// Format the def's markdown.
    /// This both generates HTML versions of everything and also replaces the original markdown
    /// with an auto-linked version.
    func visit(defItem: DefItem, parents: [Item]) {
        // currentCodeLanguage = defItem.nativeLanguage XXX TODO
        defItem.documentation.format { render(md: $0) }
        defItem.topic?.format { renderInline(md: $0 )}
        defItem.deprecationNotice?.format { render(md: $0) }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        currentCodeLanguage = nil
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        currentCodeLanguage = nil
        guideItem.content.format { render(md: $0) }
    }

    // 1 - build markdown AST
    // 2 - autolink pass, walk for `code` nodes and wrap in link
    // 3 - roundtrip to markdown and replace original
    // 4 - fixup pass for html rendering
    // 5 - render that as html
    func render(md: Markdown) -> (Markdown, Html) {
        guard let doc = CMDocument(markdown: md) else {
            logDebug("Couldn't parse and render markdown '\(md)'.")
            return (md, Html(""))
        }

        doHtmlFormatting(doc: doc)

        let html = doc.node.renderHtml()

        return (md, html)
    }

    /// Render for some inline html, stripping the outer paragraph element.
    func renderInline(md: Markdown) -> (Markdown, Html) {
        let (md, html) = render(md: md)
        let inlineHtml = html.html.re_sub("^<p>|</p>$", with: "")
        return (md, Html(inlineHtml))
    }

    // 4 - fixup pass for html rendering
    //     a) replace headings with custom nodes adding styles and tags
    //     b) create scaffolding around callouts
    //     c) code blocks language rewrite for prism / default
    //     d) math reformatting
    func doHtmlFormatting(doc: CMDocument) {
        guard let iterator = Iterator(node: doc.node) else {
            logWarning("Can't create iterator")
            return
        }

        let headingUniquer = StringUniquer()

        try! iterator.enumerate { node, event in
            guard event == .enter else {
                return false // keep going
            }
            if node.type == .heading {
                let anchorId = headingUniquer.unique(node.renderPlainText().slugged)
                let level = node.headingLevel
                let headingNode = CMNode(type: .customBlock)
                try headingNode.setCustomOnEnter(
                    #"""
                    <h\#(level) class="j2-anchor j2-heading" id="\#(anchorId)">
                    <span data-anchor-id="\#(anchorId)">
                    """#)
                try headingNode.setCustomOnExit("</span></h\(level)>")

                headingNode.replaceInTree(node: node)
                iterator.reset(to: headingNode, eventType: .enter)
            }
            else if node.type == .codeBlock {
                if let language = node.fencedCodeInfo,
                    !language.isEmpty {
                    if ["objc", "obj-c", "obj_c"].contains(language) {
                        try node.setFencedCodeInfo("objectivec")
                    }
                } else {
                    try node.setFencedCodeInfo(defaultCodeLanguage.rawValue)
                }
            }
            else if node.maybeCalloutList {
                var iteratorReset = false
                node.forEachCallout { listItem, text, callout in
                    guard callout.isNormalCallout else {
                        return
                    }
                    let calloutClass = callout.title.slugged
                    let calloutNode = CMNode(type: .customBlock)
                    try! calloutNode.setCustomOnEnter(
                        #"""
                        <div class="j2-callout j2-callout-\#(calloutClass)">
                        <div class="j2-callout-title" role="heading" aria-level="6">\#(callout.title)</div>
                        """#)
                    try! calloutNode.setCustomOnExit("</div>")

                    // Position before the entire list, take the listitem's content
                    try! calloutNode.insertIntoTree(beforeNode: node)
                    text.removeCalloutTitle(callout)
                    calloutNode.moveChildren(from: listItem)
                    listItem.unlink()
                    // Still have to traverse the callout[s]' content - and the
                    // list node may vanish out from under us if all it contained
                    // was callouts!
                    if !iteratorReset {
                        iteratorReset = true
                        iterator.reset(to: calloutNode, eventType: .enter)
                    }
                }
            }
            return false // keep going
        }
    }
}
