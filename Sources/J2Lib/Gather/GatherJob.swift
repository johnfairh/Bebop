//
//  GatherJob.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

enum GatherJob {
    case swift(moduleName: String?)

    func execute() throws -> [(moduleName: String, pass: GatherModulePass)] {
        switch self {
        case .swift(moduleName: let moduleName):
            guard let module = Module(xcodeBuildArguments: [], name: moduleName) else {
                throw OptionsError("SourceKitten unhappy")
            }

            let filesInfo = module.docs.map { swiftDoc in
                (swiftDoc.file.path ?? "(no path)",
                 GatherDef(rootSourceKittenDict: swiftDoc.docsDictionary))
            }

            return [(module.name, GatherModulePass(index: 0, defs: filesInfo))]
        }
    }
}
