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

/// Strongly-typed wrapper for markdown documents
public struct Markdown: CustomStringConvertible, Hashable {
    public let md: String

    public init(_ md: String) {
        self.md = md
    }

    public var description: String {
        md
    }
}

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
}

// MARK: Callout matcher

public struct CMCallout {
    public let title: String
    public let body: String
    public let format: Format

    private func hasTitle(_ match: String) -> Bool {
        format == .other && title.lowercased() == match
    }

    public var isReturns: Bool { hasTitle("returns") }

    public var isLocalizationKey: Bool { hasTitle("localizationkey") }

    public var isParameters: Bool { hasTitle("parameters") }

    public var isParameter: Bool { format == .parameter }

    public var isNormalCallout: Bool {
        format == .custom ||
            (format == .other && CMCallout.knownCallouts.contains(title))
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
                    title = String(matches[1])
                    body = String(matches[2])
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
