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
    case swift(moduleName: String?, srcDir: URL?, buildTool: GatherBuildTool?)

    func execute() throws -> [(moduleName: String, pass: GatherModulePass)] {
        switch self {
        case .swift(let moduleName, let srcDir, let buildTool):
            let actualSrcDir = srcDir ?? FileManager.default.currentDirectory
            let actualBuildTool = buildTool ?? inferBuildTool(in: actualSrcDir)

            let module: Module?

            switch actualBuildTool {
            case .xcodebuild:
                module = Module(xcodeBuildArguments: [], name: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    throw OptionsError("SourceKitten unhappy") // XXXX
                }
            case .spm:
                module = Module(spmArguments: [], spmName: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    throw OptionsError("SourceKitten unhappy") // XXXX
                }
            }

            let filesInfo = module!.docs.map { swiftDoc in
                (swiftDoc.file.path ?? "(no path)",
                 GatherDef(sourceKittenDict: swiftDoc.docsDictionary))
            }

            return [(module!.name, GatherModulePass(index: 0, defs: filesInfo))]
        }
    }
}

private func inferBuildTool(in directory: URL) -> GatherBuildTool {
    guard directory.filesMatching("*.xcodeproj", "*.xcworkspace").isEmpty else {
        return .xcodebuild
    }

    // XXX check build flags

    return .spm
}
