//
//  Merge.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// `Merge` generates rich code definition data by combining gathered source-code data.
///
/// - discard stuff that didn't actually get compiled
/// - merge duplicates, combining availability
/// - resolve extensions and categories
///
/// This is the end of the sourcekit-style hashes, converted into more well-typed `Item` hierarchy.
public struct Merge: Configurable {
    /// We unique names over the entire corpus which is unnecessary but makes life easier.
    var uniquer = StringUniquer()

    public init(config: Config) {
        config.register(self)
    }
    
    public func merge(gathered: [GatherModulePass]) throws -> [DefItem] {
        let allItems = importItems(gathered: gathered)

        return allItems.mergeDefinitions()
    }
}
