//
//  GatherMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

// This is some code to destructure a markdown doc-comment into params etc.
// so they can be treated separately.  Port of jazzy callout_scanner.rb.
//
// Also picks out the `localizationKey` & removes from the flow.

// A callout may exist when there is a BulletList->ListItem->Para->Text
// node hierarchy and the text matches a certain format.
//
// There are two callout-related phases.  First during Gather we need to split out
// any parameters etc. for separate processing.  Then during Decorate we need to
// spot remaining callouts and insert custom HTML.

extension CMNode {
    struct Callout {
        let title: String
        let body: String
        let format: Format

        private func hasTitle(_ match: String) -> Bool {
            format == .other && title.lowercased() == match
        }

        var isReturns: Bool { hasTitle("returns") }

        var isLocalizationKey: Bool { hasTitle("localizationkey") }

        var isParameters: Bool { hasTitle("parameters") }

        var isParameter: Bool { format == .parameter }

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

    var asCallout: Callout? {
        stringValue.flatMap { Callout(string: $0) }
    }

    func removeCalloutTitle(_ callout: Callout) {
        precondition(type == .text)
        try? setStringValue(callout.body)
    }

    /// Vend the children of the node.  Robust against the child being deleted.
    func forEach(call: (CMNode) throws -> ()) rethrows {
        var child = firstChild
        while let node = child {
            child = node.next
            try call(node)
        }
    }

    /// Vend each callout-looking-list-item
    func forEachCallout(call: (_ listItemNode: CMNode, _ textNode: CMNode, Callout) -> () ) {
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

public class MarkdownBuilder {
    let input: Markdown
    var abstract: Markdown?
    var overview: Markdown?
    var returns: Markdown?
    var parameters: [String : Markdown] = [:]
    var localizationKey: String?

    public init(markdown: Markdown) {
        self.input = markdown
    }

    public func build() -> DefMarkdown? {
        guard let doc = try? CMDocument(text: input.description,
                                        options: [.unsafe, .smart, .validateUtf8 ],         // ?? .noBreaks
                                        extensions: .all) else {
            logInfo("Markdown: can't parse as markdown '\(input)'.")
            return nil
        }

        doc.node.forEach { node in
            guard node.type == .list && node.listType == .unordered else {
                return
            }

            node.forEachCallout { li, t, c in
                processCallout(list: node, listItem: li, text: t, callout: c)
            }
            if node.firstChild == nil {
                // We deleted every item from the list
                // node.unlink()
            }
        }

//        if let firstPara = doc.node.firstChild,
//            firstPara.type == .paragraph {
//            abstract = Markdown(firstPara.render...
//            // unlink it
//        }

        // overview is then just what's left of doc, rendered.

        return DefMarkdown(abstract: abstract, overview: overview, returns: returns, parameters: parameters)
    }

    func processCallout(list: CMNode, listItem: CMNode, text: CMNode, callout: CMNode.Callout) {
        if callout.isParameter {
            //    add to output list
            parameters[callout.title] = Markdown(callout.body)
            //    extract listItem from tree
        } else if callout.isParameters {
            if let paramsList = text.parent?.next,
                paramsList.type == .list {
                processParametersList(listItem: listItem, paramsList: paramsList)
            }
        } else if callout.isReturns {
            //    add to output list
            //    extract listItem from tree
            text.removeCalloutTitle(callout)
            returns = Markdown(callout.body)
        } else if callout.isLocalizationKey {
            //    set in output
            localizationKey = callout.body
            //    remove listItem from tree
        }
    }

    /// - parameter listItem: The listitem for the `- parameters:`.
    /// - parameter paramsList: The list nested under `listItem` - everything here is a parameter.
    func processParametersList(listItem: CMNode, paramsList: CMNode) {
        paramsList.forEachCallout { paramListItem, paramText, callout in
            parameters[callout.title] = Markdown(callout.body)
        }
        // delete the -parameters part listItem.unlink()
    }
}
