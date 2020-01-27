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
/// That may be a modelling error, tbd pending implementation of import....
enum GatherJob: Equatable {
    case swift(moduleName: String?, srcDir: URL?)

    func execute() throws -> [(moduleName: String, pass: GatherModulePass)] {
        switch self {
        case .swift(moduleName: let moduleName, let srcDir):
            guard let module = Module(xcodeBuildArguments: [], name: moduleName, inPath: srcDir) else {
                throw OptionsError("SourceKitten unhappy") // XXXX
            }

            let filesInfo = module.docs.map { swiftDoc in
                (swiftDoc.file.path ?? "(no path)",
                 GatherDef(sourceKittenDict: swiftDoc.docsDictionary))
            }

            return [(module.name, GatherModulePass(index: 0, defs: filesInfo))]
        }
    }
}

extension Module {
    init?(xcodeBuildArguments: [String], name: String?, inPath url: URL?) {
        if let url = url {
            self.init(xcodeBuildArguments: xcodeBuildArguments, name: name, inPath: url.path)
        } else {
            self.init(xcodeBuildArguments: xcodeBuildArguments, name: name)
        }
    }
}
