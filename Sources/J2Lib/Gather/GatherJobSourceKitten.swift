//
//  GatherJobSourceKitten.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// Job to get info from a set of SourceKitten source files.
//
extension GatherJob {
    struct SourceKitten: Equatable {
        let moduleName: String
        let fileURLs: [URL]
        let availability: Gather.Availability

        func execute() throws -> GatherModulePass {
            GatherModulePass(moduleName: moduleName, passIndex: 0, files: [])
        }
    }
}
