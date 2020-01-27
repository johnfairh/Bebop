//
//  GatherJob.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// A recipe to create one pass over a module.
///
/// In fact that's a lie because "import a gather.json" is also a job that can vend multiple modules and passes.
/// That may be a modelling error, tbd pending implementation of import.
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
                 GatherDef(sourceKittenDict: swiftDoc.docsDictionary))
            }

            return [(module.name, GatherModulePass(index: 0, defs: filesInfo))]
        }
    }
}
