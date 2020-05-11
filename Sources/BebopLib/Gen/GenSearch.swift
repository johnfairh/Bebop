//
//  GenSearch.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// This is quick port of the jazzy version with a tweak to include
/// both ObjC and Swift versions if the names are different.  And it includes
/// the abstract as text rather than html.
///
/// Lunr isn't the right thing for text indexing though.
///
/// Could maybe look at including the name-piece-name thing in the index, but a bit
/// scared of bulking up the json too much.
///
/// - important: All the hard-coded strings here are shared with `fw2020.js`.
final class GenSearch: Configurable {
    init(config: Config) {
        config.register(self)
    }

    struct Entry {
        let urlPath: String
        let name: String
        let abstract: Localized<String>?
        let parentName: String?

        func toDictValue(languageTag: String) -> [String: String] {
            var dict = ["name" : name]
            abstract.flatMap { dict["abstract"] = $0.get(languageTag) }
            parentName.flatMap { dict["parent_name"] = $0 }
            return dict
        }
    }

    private final class Visitor: ItemVisitorProtocol {
        var entries = [Entry]()
        func visit(defItem: DefItem, parents: [Item]) {
            entries += defItem.asSearchEntries
        }
    }

    private(set) var entries = [Entry]()

    /// Build the index from the item forest
    func buildIndex(items: [Item]) throws {
        logDebug("Gen: start building search index")
        let visitor = Visitor()
        try visitor.walk(items: items)
        entries = visitor.entries
        logDebug("Gen: done building search index: \(entries.count) entries")
    }

    /// Write a version of the index for the particular language
    func writeIndex(docRootURL: URL, languageTag: String) throws {
        logDebug("Gen: Making search index for '\(languageTag)'")
        let languageIndex = Dictionary<String, [String:String]>(uniqueKeysWithValues:
            entries.map { ($0.urlPath, $0.toDictValue(languageTag: languageTag)) }
        )
        let indexURL = docRootURL.appendingPathComponent("search.json")
        let json = try JSON.encode(languageIndex)
        try json.write(to: indexURL)
        logDebug("Gen: Wrote search index to '\(indexURL.path)'")
    }
}

// MARK: DefItem

private extension DefItem {
    var asSearchEntries: [GenSearch.Entry] {
        var entries = [GenSearch.Entry]()
        let abstract = documentation.abstract?.plainText

        entries.append(GenSearch.Entry(
            urlPath: url.url(fileExtension: ".html", language: primaryLanguage),
            name: name,
            abstract: abstract,
            parentName: (parent as? DefItem)?.name)
        )

        // Try to figure out if the other language name is different enough to
        // be worth including separately.

        if let otherName = otherLanguageName,
            let otherLanguage = secondaryLanguage,
            let otherNamePieces = secondaryNamePieces,
            primaryNamePieces.flattenedName != otherNamePieces.flattenedName {
            entries.append(GenSearch.Entry(
                urlPath: url.url(fileExtension: ".html", language: otherLanguage),
                name: otherName,
                abstract: abstract,
                parentName: (parent as? DefItem)?.name) // hmm
            )
        }

        return entries
    }
}
