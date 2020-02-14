//
//  Markdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

//
// Helpers on top of Maaku types and special knowledge about callout
// formatting.
//


// MARK: `CMDocument` helpers

extension CMDocument {
    static let options: CMDocumentOption = [.unsafe, .smart, .validateUtf8] // ?? .noBreaks
    static let extensions = CMExtensionOption.all

    /// Create a markdown doc tree from some text
    public convenience init?(markdown: Markdown) {
        do {
            try self.init(text: markdown.description, options: CMDocument.options, extensions: CMDocument.extensions)
        } catch {
            return nil
        }
    }
}

// MARK: Base `CMNode` helpers

extension CMNode {
    /// Vend the children of the node.  Robust against the child being deleted.
    public func forEach(_ call: (CMNode) throws -> ()) rethrows {
        var child = firstChild
        while let node = child {
            child = node.next
            try call(node)
        }
    }

    /// Render the tree to markdown, standard options and minimal whitespace.
    public func renderMarkdown() -> Markdown {
        do {
            let md = try renderCommonMark(CMDocument.options, width: 80)
            return Markdown(md.trimmingTrailingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return Markdown("")
        }
    }

    /// Render the tree to html, standard options and minimal whitespace.
    public func renderHtml() -> Html {
        do {
            let html = try renderHtml(CMDocument.options, extensions: CMDocument.extensions)
            return Html(html.trimmingTrailingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return Html("")
        }
    }

    /// Render the tree to plaintext, standard options and minimal whitespace.
    public func renderPlainText() -> String {
        do {
            let text = try renderPlainText(CMDocument.options, width: 80)
            return text.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }

    /// Move all children from the given node after our children
    public func moveChildren(from node: CMNode) {
        while let child = node.firstChild {
            try! child.insertIntoTree(asLastChildOf: self)
        }
    }

    /// Replace a node in the tree, taking its children.  The node being replaced ends up unlinked.
    public func replaceInTree(node: CMNode) {
        moveChildren(from: node)
        try! insertIntoTree(beforeNode: node)
        node.unlink()
    }
}

// MARK: Callout matcher

public struct CMCallout {
    public let title: String
    public let body: String
    public let format: Format

    private var lowerTitle: String {
        title.lowercased()
    }

    private func hasTitle(_ match: String) -> Bool {
        format == .other && lowerTitle == match
    }

    public var isReturns: Bool { hasTitle("returns") }

    public var isLocalizationKey: Bool { hasTitle("localizationkey") }

    public var isParameters: Bool { hasTitle("parameters") }

    public var isParameter: Bool { format == .parameter }

    public var isNormalCallout: Bool {
        format == .custom ||
            (format == .other && CMCallout.knownCallouts.contains(lowerTitle))
    }

    /// Four slightly different formats wrapped up here:
    ///   Callout(XXXX XXXX):YYYY    (Custom callout)
    ///   Parameter XXXX: YYYY         (Swift)
    ///   Parameter: XXXX YYYY         (ObjC)
    ///   XXXX:YYYYY                         (everything else, covers parameters: nesting)
    public enum Format {
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

    public init?(string: String) {
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
    public var asCallout: CMCallout? {
        stringValue.flatMap { CMCallout(string: $0) }
    }

    /// Edit this node's text to remove the callout title.
    public func removeCalloutTitle(_ callout: CMCallout) {
        precondition(type == .text)
        try? setStringValue(callout.body)
    }

    /// Might this node contain callouts?
    public var maybeCalloutList: Bool {
        type == .list && listType == .unordered
    }

    /// Vend each callout-looking-list-item.
    /// Only valid called for `.list` markdown nodes.
    ///
    /// A callout may exist when there is a BulletList->ListItem->Para->Text
    /// node hierarchy and the text matches a certain format.
    ///
    public func forEachCallout(_ call: (_ listItemNode: CMNode, _ textNode: CMNode, CMCallout) -> () ) {
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
    public func forEachCallout(_ call: (_ list: CMNode, _ listItem: CMNode, _ text: CMNode, CMCallout) -> ()) {
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
