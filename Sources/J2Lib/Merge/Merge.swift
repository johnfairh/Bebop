//
//  Merge.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

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
        gathered.map { pass in
            pass.files.map { fileDef -> [DefItem] in
                let filePathName = fileDef.0
                let rootDef = fileDef.1
                guard rootDef.sourceKittenDict["key.diagnostic_stage"] != nil else {
                    logWarning(.localized(.wrnMergeMissingRoot, filePathName, pass.passIndex))
                    return []
                }

                return rootDef.children.compactMap { gatherDef in
                    DefItem(moduleName: pass.moduleName,
                            passIndex: pass.passIndex,
                            gatherDef: gatherDef,
                            uniquer: uniquer)
                }
            }.flatMap { $0 }
        }.flatMap { $0 }
    }
}
