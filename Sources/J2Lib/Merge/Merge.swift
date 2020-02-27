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
        let allItems = createItems(gathered: gathered)

        return allItems.merge()
    }
}

extension Array where Element == DefItem {
    func merge() -> [DefItem] {
        var mergedItems = [DefItem]()
        var index = MergeIndex()
        forEach { item in
            if !index.addTestMerged(item: item) {
                mergedItems.append(item)
            }
        }

        return mergedItems
    }
}

struct MergeIndex {
    final class Name {
        var usrMap = [String: DefItem]()
        init(item: DefItem) {
            usrMap[item.usr] = item
        }

        func addTestMerged(item: DefItem) -> Bool {
            if let currentItem = usrMap[item.usr] {
                // woah merge
                return false
            }
            usrMap[item.usr] = item
            return false
        }
    }

    final class Module {
        var nameMap = [String: Name]()
        init(item: DefItem) {
            _ = addTestMerged(item: item)
        }

        func addTestMerged(item: DefItem) -> Bool {
            if let name = nameMap[item.name] {
                return name.addTestMerged(item: item)
            }
            nameMap[item.name] = Name(item: item)
            return false
        }
    }
    var modules = [String: Module]()

    mutating func addTestMerged(item: DefItem) -> Bool {
        if let module = modules[item.location.moduleName] {
            return module.addTestMerged(item: item)
        }
        modules[item.location.moduleName] = Module(item: item)
        return false
    }
}
