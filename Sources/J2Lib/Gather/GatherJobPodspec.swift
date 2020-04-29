//
//  GatherJobPodspec.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Podspec

extension GatherJob {
    struct Podspec: Equatable {
        let moduleName: String?
        let podspecURL: URL
        let podSources: [String]
        let availability: Gather.Availability

        func execute() throws -> [GatherModulePass] {
            []
        }
    }
}
