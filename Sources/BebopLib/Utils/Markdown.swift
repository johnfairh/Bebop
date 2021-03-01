//
//  Markdown.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import Maaku

//
// Helpers on top of Maaku types and special knowledge about callout
// formatting ported from jazzy callout_scanner.
//

// MARK: `CMDocument` helpers

extension CMDocument {
    static let options: CMDocumentOption = [.unsafe, .smart, .validateUtf8] // ?? .noBreaks
    static let extensions = CMExtensionOption.all

    /// Create a markdown doc tree from some text
    convenience init?(markdown: Markdown) {
        do {
            try self.init(text: markdown.description, options: CMDocument.options, extensions: CMDocument.extensions)
        } catch {
            return nil
        }
    }

    /// Simple helper to go straight from markdown to HTML
    static func format(md: Markdown, languageTag: String) -> (Markdown, Html) {
        guard let doc = CMDocument(markdown: md) else {
            return (md, Html(""))
        }
        return (md, doc.node.renderHtml())
    }

    /// Remove and return any lede paragraph
    func removeFirstParagraph() -> CMNode? {
        if let firstPara = node.firstChild,
            firstPara.type == .paragraph {
            firstPara.unlink()
            return firstPara
        }
        return nil
    }
}

// MARK: Base `CMNode` helpers

extension CMNode {
    /// Render the tree to markdown, standard options and minimal whitespace.
    func renderMarkdown() -> Markdown {
        do {
            let md = try renderCommonMark(CMDocument.options, width: 0)
            return Markdown(md.trimmingTrailingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return Markdown("")
        }
    }

    /// Render the tree to html, standard options and minimal whitespace.
    func renderHtml() -> Html {
        do {
            let html = try renderHtml(CMDocument.options, extensions: CMDocument.extensions)
            return Html(html.trimmingTrailingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return Html("")
        }
    }

    /// Render the tree to plaintext, standard options and minimal whitespace.
    func renderPlainText() -> String {
        do {
            let text = try renderPlainText(CMDocument.options, width: 0)
            return text.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    /// Move all children from the given node after our children
    func moveChildren(from node: CMNode) {
        while let child = node.firstChild {
            try! child.insertIntoTree(asLastChildOf: self)
        }
    }

    /// Replace a node in the tree, taking its children.  The node being replaced ends up unlinked.
    func replaceInTree(node: CMNode) {
        moveChildren(from: node)
        try! insertIntoTree(beforeNode: node)
        node.unlink()
    }

    /// Create a new 'custom' node with content that is rendered before & after its children,
    /// independent of the render format requested on the tree.
    convenience init(customEnter: String, customExit: String) {
        self.init(type: .customBlock)
        try! setCustomOnEnter(customEnter)
        try! setCustomOnExit(customExit)
    }
}

// MARK: Para list helper
extension CMDocument {
    /// Take some paragraphs and turn into a bullet list, one bullet per para.
    /// This is about things like 'declnotes' or 'deprecation notes' and really reveals
    /// the modelling error - should have explicitly modelled the note elements rather than treating
    /// them as a blob.
    static func parasToList(markdown: Markdown) -> Markdown {
        guard let doc = CMDocument.init(markdown: markdown) else {
            return markdown
        }
        let listNode = CMNode(type: .list)
        try! listNode.setListType(.unordered)
        while let node = doc.removeFirstParagraph() {
            let itemNode = CMNode(type: .item)
            try! node.insertIntoTree(asFirstChildOf: itemNode)
            try! itemNode.insertIntoTree(asLastChildOf: listNode)
        }
        return listNode.renderMarkdown()
    }

    static func parasToList(text: Localized<Markdown>) -> Localized<Markdown> {
        text.mapValues { parasToList(markdown: $0) }
    }
}

// MARK: Callout matcher

struct CMCallout {
    let title: String
    let body: String
    let format: Format

    private var lowerTitle: String {
        title.lowercased()
    }

    private func hasTitle(_ match: String) -> Bool {
        format == .other && lowerTitle == match
    }

    var isReturns: Bool { hasTitle("returns") }

    var isThrows: Bool { hasTitle("throws") }

    var isLocalizationKey: Bool { hasTitle("localizationkey") }

    var isParameters: Bool { hasTitle("parameters") }

    var isParameter: Bool { format == .parameter }

    var isNormalCallout: Bool {
        format == .custom ||
            (format == .other && CMCallout.knownCallouts.contains(lowerTitle))
    }

    /// Four slightly different formats wrapped up here:
    ///   Callout(XXXX XXXX):YYYY    (Custom callout)
    ///   Parameter XXXX: YYYY         (Swift)
    ///   Parameter: XXXX YYYY         (ObjC)
    ///   XXXX:YYYYY                         (everything else, covers parameters: nesting)
    enum Format {
        case parameter
        case other
        case custom

        var regexps: [String] {
            switch self {
            case .custom:
                return [#"\A\s*callout\((.+)\)\s*:\s*(.*)\Z"#]
            case .parameter:
                return [
                    #"\A\s*parameter\s+(\S+)\s*:\s*(.*)\Z"#,
                    #"\A\s*parameter\s*:\s*(\S+)\s+(.*)\Z"#
                ]
            case .other:
                return [#"\A\s*(\S+)\s*:\s*(.*)\Z"#]
            }
        }
    }

    init?(string: String) {
        for format in [Format.custom, Format.parameter, Format.other] { // order dependency here...
            for re in format.regexps {
                if let matches = string.re_match(re, options: [.i, .m]) {
                    title = matches[1]
                    body = matches[2]
                    self.format = format
                    return
                }
            }
        }
        return nil
    }
}

// MARK: CMNode - CMCallout interlock

extension CMNode {
    /// Try to interpret this node as a callout
    var asCallout: CMCallout? {
        stringValue.flatMap { CMCallout(string: $0) }
    }

    /// Edit this node's text to remove the callout title.
    func removeCalloutTitle(_ callout: CMCallout) {
        precondition(type == .text)
        try? setStringValue(callout.body)
    }

    /// Might this node contain callouts?
    var maybeCalloutList: Bool {
        type == .list && listType == .unordered
    }

    /// Vend each callout-looking-list-item.
    /// Only valid called for `.list` markdown nodes.
    ///
    /// A callout may exist when there is a BulletList->ListItem->Para->Text
    /// node hierarchy and the text matches a certain format.
    ///
    func forEachCallout(_ call: (_ listItemNode: CMNode, _ textNode: CMNode, CMCallout) -> () ) {
        precondition(type == .list)
        forEach { listItemNode in
            if listItemNode.type == .item,
                let paraNode = listItemNode.firstChild,
                paraNode.type == .paragraph,
                let textNode = paraNode.firstChild,
                textNode.type == .text,
                let callout = textNode.asCallout {
                call(listItemNode, textNode, callout)
            }
        }
        if firstChild == nil {
            // We deleted every item from the list
            unlink()
        }
    }
}

// MARK: CMDocument callout scanner

extension CMDocument {
    func forEachCallout(_ call: (_ list: CMNode, _ listItem: CMNode, _ text: CMNode, CMCallout) -> ()) {
        node.forEach { node in
            guard node.maybeCalloutList else {
                return
            }

            node.forEachCallout { li, t, c in
                call(node, li, t, c)
            }
        }
    }
}

// MARK: Officially Known Callouts

extension CMCallout {
    /// List of Swift callouts, excluding param/returns.
    /// Plus 'example' from playgrounds because people use it all the time.
    /// Plus 'see' from Objective-C.
    /// https://github.com/apple/swift/blob/master/include/swift/Markup/SimpleFields.def
    private static let knownCallouts = Set<String>([
        "attention",
        "author",
        "authors",
        "bug",
        "complexity",
        "copyright",
        "date",
        "experiment",
        "important",
        "invariant",
        "localizationkey",
        "mutatingvariant",
        "nonmutatingvariant",
        "note",
        "postcondition",
        "precondition",
        "remark",
        "remarks",
        "throws",
        "requires",
        "seealso",
        "since",
        "tag",
        "todo",
        "version",
        "warning",
        "keyword",
        "recommended",
        "recommendedover",
        "example",
        "see",
    ])
}
