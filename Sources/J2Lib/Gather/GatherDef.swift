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
    public let children: [GatherDef]
    /// SourceKitten hash _except_ the substructure key
    public let sourceKittenDict: SourceKittenDict
    /// Definition type according to sourcekitten hash - `nil` means missing kind.
    public let kind: DefKind?
    /// Multi-faceted Swift declaration info
    public let swiftDeclaration: SwiftDeclaration?
    /// Multi-faceted ObjC declaration info
    public let objCDeclaration: ObjCDeclaration?
    /// Documentation - raw from source, superseded by `translatedDocs` after garnish
    public let documentation: FlatDefDocs?
    public let localizationKey: String?

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
        guard let kind = DefKind.from(key: kindValue, dict: sourceKittenDict) else {
            logWarning(.localized(.wrnSktnKind, kindValue))
            Stats.inc(.gatherFailure)
            return nil
        }
        self.kind = kind

        if let docComment = sourceKittenDict.documentationComment {
            let docsBuilder = MarkdownBuilder(markdown: Markdown(docComment))
            self.documentation = docsBuilder.build()
            self.localizationKey = docsBuilder.localizationKey
        } else if kind.isSwift, let _ = sourceKittenDict.fullXMLDocs {
            self.documentation = nil //FlatDefDocs(abstract: Markdown("xml"), source: .inherited)
            self.localizationKey = nil
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
    public internal(set) var translatedDocs = LocalizedDefDocs()

    /// Piecemeal initializer for json-import and test
    init(children: [GatherDef],
         sourceKittenDict: SourceKittenDict,
         kind: DefKind?,
         swiftDeclaration: SwiftDeclaration?,
         objCDeclaration: ObjCDeclaration?,
         documentation: FlatDefDocs?,
         localizationKey: String?,
         translatedDocs: LocalizedDefDocs?) {
        self.children = children
        self.sourceKittenDict = sourceKittenDict
        self.kind = kind
        self.swiftDeclaration = swiftDeclaration
        self.objCDeclaration = objCDeclaration
        self.documentation = documentation
        self.localizationKey = localizationKey
        translatedDocs.flatMap { self.translatedDocs = $0 }
        Stats.inc(.gatherDef)
    }
}

/// Upgraded `DefKind` constructor that works around various omissions and bugs in the
/// input layer to give a most-correct view of the kind.  Kludgey by its very nature.
extension DefKind {
    static func from(key: String, dict: SourceKittenDict) -> DefKind? {
        DefKind.from(key: key)?.adjusted(by: dict)
    }

    private func adjusted(by dict: SourceKittenDict) -> DefKind {
        guard let newKind = isSwift ? adjustedSwift(dict: dict) : adjustedObjC(dict: dict) else {
            return self
        }
        return DefKind.from(kind: newKind)
    }

    private func adjustedSwift(dict: SourceKittenDict) -> DeclarationKind? {
        if hasSwiftFunctionName, let name = dict.name {
            if name.re_isMatch(#"^init[?!]?\("#) {
                return SwiftDeclarationKind.functionConstructor
            }
            if name == "deinit" {
                return SwiftDeclarationKind.functionDestructor
            }
            if isSwiftSubscript, let decl = dict.parsedDeclaration {
                if decl.re_isMatch(#"\bstatic\b"#) {
                    return SwiftDeclarationKind2.functionSubscriptStatic
                } else if decl.re_isMatch(#"\bclass\b"#) {
                    return SwiftDeclarationKind2.functionSubscriptClass
                }
            }
        }
        return nil
    }

    private func adjustedObjC(dict: SourceKittenDict) -> DeclarationKind? {
        if let name = dict.name,
            isObjCMethod,
            name.re_isMatch(#"[+-]\s*init"#) {
            return ObjCDeclarationKind.initializer
        } else if isObjCProperty,
            let decl = dict.parsedDeclaration,
            decl.re_isMatch(#"@property\s+\(.*?class.*?\)"#) {
            return ObjCDeclarationKind2.propertyClass
        }
        return nil
    }
}
