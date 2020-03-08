//
//  GatherDef.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// Type representing a code definition (or some weird SourceKit not-a-node).
///
/// Originally created from a SourceKitten dictionary this is augmented by successive
/// garnishings before gather is complete.
public final class GatherDef {
    /// Child definitions, constructed from the SourceKitten substructure
    let children: [GatherDef]
    /// SourceKitten hash _except_ the substructure key
    let sourceKittenDict: SourceKittenDict
    /// Definition type according to sourcekitten hash - `nil` means missing kind.
    let kind: DefKind?
    /// Multi-faceted Swift declaration info
    let swiftDeclaration: SwiftDeclaration?
    /// Multi-faceted ObjC declaration info
    let objCDeclaration: ObjCDeclaration?
    /// Documentation
    let documentation: FlatDefDocs?
    let localizationKey: String?

    init?(sourceKittenDict: SourceKittenDict,
          parentNameComponents: [String],
          file: SourceKittenFramework.File?,
          availability: Gather.Availability) {
        var dict = sourceKittenDict
        let name = sourceKittenDict.name
        let nameComponents = name.flatMap { parentNameComponents + [$0] } ?? parentNameComponents
        let substructure = dict.removeSubstructure()
        self.children = substructure.compactMap {
            GatherDef(sourceKittenDict: $0,
                      parentNameComponents: nameComponents,
                      file: file,
                      availability: availability)
        }

        guard let kindValue = dict.kind else {
            self.kind = nil
            self.documentation = nil
            self.localizationKey = nil
            self.swiftDeclaration = nil
            self.objCDeclaration = nil
            self.sourceKittenDict = dict
            Stats.inc(.gatherDef)
            return
        }
        guard let kind = DefKind.from(key: kindValue, name: name ?? "") else {
            logWarning(.localized(.wrnSktnKind, kindValue))
            Stats.inc(.gatherFailure)
            return nil
        }
        self.kind = kind

        if let docComment = sourceKittenDict.documentationComment {
            let docsBuilder = MarkdownBuilder(markdown: Markdown(docComment))
            self.documentation = docsBuilder.build()
            self.localizationKey = docsBuilder.localizationKey
        } else {
            self.documentation = nil
            self.localizationKey = nil
        }

        if kind.isSwift {
            self.swiftDeclaration =
                SwiftDeclarationBuilder(dict: dict,
                                        nameComponents: nameComponents,
                                        file: file,
                                        kind: kind,
                                        availabilityRules: availability).build()
            self.objCDeclaration = nil
        } else {
            // Work around missing declarations for categories
            if kind.isObjCCategory,
                dict.swiftDeclaration == nil,
                let name = dict.name,
                let brokenName = ObjCCategoryName(name) {
                dict[SwiftDocKey.swiftDeclaration.rawValue] = "extension \(brokenName.className)"
                dict[SwiftDocKey.swiftName.rawValue] = brokenName.className
            }

            self.swiftDeclaration =
                ObjCSwiftDeclarationBuilder(objCDict: dict,
                                            kind: kind,
                                            availability: availability).build()
            self.objCDeclaration =
                ObjCDeclarationBuilder(dict: dict, kind: kind).build()
        }
        self.sourceKittenDict = dict
        Stats.inc(.gatherDef)
    }

    // Things calculated after init
    var translatedDocs = LocalizedDefDocs()

    /// Test helper
    init(sourceKittenDict: SourceKittenDict, children: [GatherDef]) {
        self.children = children
        self.sourceKittenDict = sourceKittenDict
        self.kind = nil
        self.swiftDeclaration = nil
        self.objCDeclaration = nil
        self.documentation = nil
        self.localizationKey = nil
    }
}
