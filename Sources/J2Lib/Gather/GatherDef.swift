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
    let sourceKittenDict: SourceKittenDict

    init(rootSourceKittenDict: SourceKittenDict) {
        sourceKittenDict = rootSourceKittenDict
    }
}
