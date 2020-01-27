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

public struct GatherDef {
    let children: [GatherDef]
    let sourceKittenDict: SourceKittenDict

    init(sourceKittenDict: SourceKittenDict) {
        var dict = sourceKittenDict
        let substructure = dict.removeValue(forKey: SwiftDocKey.substructure.rawValue) as? [SourceKittenDict] ?? []
        self.children = substructure.map(GatherDef.init)
        self.sourceKittenDict = dict
    }
}
