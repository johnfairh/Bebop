//
//  GatherDef.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

typealias SourceKittenDict = [String: SourceKitRepresentable]

/// Type representing a code definition (or some weird SourceKit not-a-node).
///
/// Originally created from a SourceKitten dictionary this is augmented by successive
/// garnishings before gather is complete.
public final class GatherDef {
    /// Child definitions, constructed from the SourceKitten substructure
    let children: [GatherDef]
    /// SourceKitten hash _except_ the substructure key
    let sourceKittenDict: SourceKittenDict
    /// Definition type according to sourcekitten hash - `nil` means unknown kind.
    let kind: DefKind?
    /// Multi-faceted Swift declaration info
    let swiftDeclaration: SwiftDeclaration?
    /// Documentation
    let documentation: FlatDefDocs?
    let localizationKey: String?

    init(sourceKittenDict: SourceKittenDict,
         file: SourceKittenFramework.File?,
         availabilityRules: GatherAvailabilityRules) {
        var dict = sourceKittenDict
        let substructure = dict.removeValue(forKey: SwiftDocKey.substructure.rawValue) as? [SourceKittenDict] ?? []
        self.children = substructure.map {
            GatherDef(sourceKittenDict: $0, file: file, availabilityRules: availabilityRules)
        }
        self.sourceKittenDict = dict
        self.kind = (dict[SwiftDocKey.kind.rawValue] as? String).flatMap { DefKind.from(key: $0) }

        self.swiftDeclaration =
            SwiftDeclarationBuilder(dict: sourceKittenDict,
                                    file: file,
                                    kind: kind,
                                    availabilityRules: availabilityRules).build()

        if let docComment = sourceKittenDict[SwiftDocKey.documentationComment.rawValue] as? String {
            let docsBuilder = MarkdownBuilder(markdown: Markdown(docComment))
            self.documentation = docsBuilder.build()
            self.localizationKey = docsBuilder.localizationKey
        } else {
            self.documentation = nil
            self.localizationKey = nil
        }
    }

    // Things calculated after init
    var translatedDocs = LocalizedDefDocs()
}
