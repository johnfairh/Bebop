//
//  GatherMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

/// A type to destructure a markdown doc-comment into params etc.
/// so they can be treated separately.  Port of jazzy callout_scanner.rb.
///
/// Also picks out the `localizationKey`.
public class MarkdownBuilder {
    let input: Markdown
    private var abstract: Markdown?
    private var overview: Markdown?
    private var returns: Markdown?
    private var parameters: [FlatDefDocs.Param] = []
    private(set) var localizationKey: String?

    public init(markdown: Markdown) {
        self.input = markdown
    }

    /// Try to destructure this doc comment markdown into pieces.
    /// Also update `localizationKey`
    public func build() -> FlatDefDocs? {
        guard let doc = CMDocument(markdown: input) else {
            logDebug("Markdown: can't parse as markdown '\(input)'.")
            return nil
        }

        doc.node.forEach { node in
            guard node.maybeCalloutList else {
                return
            }

            node.forEachCallout { li, t, c in
                processCallout(list: node, listItem: li, text: t, callout: c)
            }
            if node.firstChild == nil {
                // We deleted every item from the list
                node.unlink()
            }
        }

        // Take any first paragraph as the 'abstract'
        if let firstPara = doc.node.firstChild,
            firstPara.type == .paragraph {
            firstPara.unlink()
            abstract = firstPara.renderMarkdown()
        }

        // overview is what's left if anything
        if doc.node.firstChild != nil {
            overview = doc.node.renderMarkdown()
        } else if abstract == nil &&
                  returns == nil &&
                  parameters.count == 0 {
            // preserve 'empty' string to avoid wrong 'undocumented' categorization,
            // which is maybe fair but they did write a doc comment so...
            overview = Markdown("")
        }

        return FlatDefDocs(abstract: abstract,
                           overview: overview,
                           returns: returns,
                           parameters: parameters)
    }

    /// Handle a top-level callout - side-effect `parameters` `returns` `localizationKey`.
    func processCallout(list: CMNode, listItem: CMNode, text: CMNode, callout: CMCallout) {
        // Helper to add a parameter
        func addParam(listItem: CMNode, text: CMNode, callout: CMCallout) {
            parameters.append(
                .init(name: callout.title,
                      description: extractCallout(listItem: listItem, text: text, callout: callout)))
        }

        if callout.isParameter {
            addParam(listItem: listItem, text: text, callout: callout)
        } else if callout.isParameters {
            if let paramsList = text.parent?.next,
                paramsList.maybeCalloutList {
                paramsList.forEachCallout(addParam)
                // delete the '- parameters:' part
                listItem.unlink()
            }
        } else if callout.isReturns {
            returns = extractCallout(listItem: listItem, text: text, callout: callout)
        } else if callout.isLocalizationKey {
            localizationKey = callout.body
        }
        // else: a regular callout (eg. warning/custom) - nothing to do at this stage
    }

    func extractCallout(listItem: CMNode, text: CMNode, callout: CMCallout) -> Markdown {
        let newDoc = CMNode(type: .document)
        text.removeCalloutTitle(callout)
        while let child = listItem.firstChild {
            try! child.insertIntoTree(asLastChildOf: newDoc)
        }
        listItem.unlink()
        return newDoc.renderMarkdown()
    }
}
