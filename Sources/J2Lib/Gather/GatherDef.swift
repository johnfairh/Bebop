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
public struct GatherDef {
    /// Child definitions, constructed from the SourceKitten substructure
    let children: [GatherDef]
    /// SourceKitten hash _except_ the substructure key
    let sourceKittenDict: SourceKittenDict
    /// Definition type according to sourcekitten hash - `nil` means unknown kind.
    let kind: DefKind?
    /// Multi-faceted Swift declaration info
    let swiftDeclaration: SwiftDeclaration?

    init(sourceKittenDict: SourceKittenDict, file: SourceKittenFramework.File?) {
        var dict = sourceKittenDict
        let substructure = dict.removeValue(forKey: SwiftDocKey.substructure.rawValue) as? [SourceKittenDict] ?? []
        self.children = substructure.map { GatherDef(sourceKittenDict: $0, file: file) }
        self.sourceKittenDict = dict
        self.kind = (dict[SwiftDocKey.kind.rawValue] as? String).flatMap { DefKind.from(key: $0) }

        self.swiftDeclaration = SwiftDeclarationBuilder(dict: sourceKittenDict, file: file).build()
    }
}
