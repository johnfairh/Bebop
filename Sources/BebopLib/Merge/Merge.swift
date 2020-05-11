//
//  Merge.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
    private let importer: MergeImport
    private let definitions: MergeDefinitions
    private let filter: MergeFilter

    // Unit test controls
    var enableFilter = true
    var enablePhase2 = true

    public init(config: Config) {
        importer = MergeImport(config: config)
        definitions = MergeDefinitions(config: config)
        filter = MergeFilter(config: config)
        config.register(self)
    }
    
    public func merge(gathered: [GatherModulePass]) throws -> [DefItem] {
        logDebug("Merge: import")
        var items = importer.importItems(gathered: gathered)
        logDebug("Merge: merge phase 1")
        items = definitions.mergePhase1(items: items)
        if enableFilter {
            logDebug("Merge: filter")
            items = filter.filter(items: items)
        }
        if enablePhase2 {
            logDebug("Merge: merge phase 2")
            items = definitions.mergePhase2(items: items)
        }
        return items
    }
}
