//
//  GatherMarkdown.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import Maaku

/// A type to destructure a markdown doc-comment into params etc.
/// so they can be treated separately.  Port of jazzy callout_scanner.rb.
///
/// Also picks out the `localizationKey`.
final class MarkdownBuilder {
    let input: Markdown
    private let source: DefDocSource
    private var abstract: Markdown?
    private var discussion: Markdown?
    private var returns: Markdown?
    private var parameters: [FlatDefDocs.Param] = []
    private(set) var localizationKey: String?

    init(markdown: Markdown, source: DefDocSource) {
        self.input = markdown
        self.source = source // somewhat trampy
    }

    /// Try to destructure this doc comment markdown into pieces.
    /// Also update `localizationKey`
    func build() -> FlatDefDocs? {
        guard let doc = CMDocument(markdown: input) else {
            logDebug("Markdown: can't parse as markdown '\(input)'.")
            return nil
        }

        doc.forEachCallout { processCallout(list: $0, listItem: $1, text: $2, callout: $3) }

        // Take any first paragraph as the 'abstract'
        if let firstPara = doc.removeFirstParagraph() {
            abstract = firstPara.renderMarkdown()
        }

        // discussion is what's left if anything
        if doc.node.firstChild != nil {
            discussion = doc.node.renderMarkdown()
        } else if abstract == nil &&
                  returns == nil &&
                  parameters.count == 0 {
            // preserve 'empty' string to avoid wrong 'undocumented' categorization,
            // which is maybe fair but they did write a doc comment so...
            discussion = Markdown("")
        }

        return FlatDefDocs(abstract: abstract,
                           discussion: discussion,
                           returns: returns,
                           parameters: parameters,
                           source: source)
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
        newDoc.moveChildren(from: listItem)
        listItem.unlink()
        return newDoc.renderMarkdown()
    }
}
