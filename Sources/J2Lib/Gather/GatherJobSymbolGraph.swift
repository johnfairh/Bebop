//
//  GatherJobSymbolGraph.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Import from Swift SymbolGraph Extract JSON

extension GatherJob {
    struct SymbolGraph: Equatable {
        let moduleName: String
        let srcDir: URL?
        let buildToolArgs: [String]
        let sdk: Gather.Sdk
        let target: String
        let availability: Gather.Availability

        func execute() throws -> GatherModulePass {
            GatherModulePass(moduleName: "", passIndex: 0, imported: false, files: [])
        }
    }
}
