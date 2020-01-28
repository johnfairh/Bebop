//
//  Merge.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public struct Merge {
    public init(config: Config) {
    }
    
    public func merge(gathered: GatherModules) throws -> [DeclDef] {
        // all I do with this data structure is build it and take it apart again!
        gathered.modules.map { module in
            module.passes.map { pass in
                pass.defs.compactMap { def in
                    DeclDef(moduleName: module.name, passIndex: pass.index, gatherDef: def.1)
                }
            }.flatMap { $0 }
        }.flatMap { $0 }
    }
}
