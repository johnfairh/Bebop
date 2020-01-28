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
    case swift(moduleName: String?, srcDir: URL?, buildTool: GatherBuildTool?, buildToolArgs: [String])

    func execute() throws -> [(moduleName: String, pass: GatherModulePass)] {
        switch self {
        case .swift(let moduleName, let srcDir, let buildTool, let buildToolArgs):
            let actualSrcDir = srcDir ?? FileManager.default.currentDirectory
            let actualBuildTool = buildTool ?? inferBuildTool(in: actualSrcDir, buildToolArgs: buildToolArgs)

            let module: Module?

            switch actualBuildTool {
            case .xcodebuild:
                module = Module(xcodeBuildArguments: buildToolArgs, name: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    if let moduleName = moduleName {
                        throw GatherError(.localized("err-sktn-xcode-mod", moduleName))
                    } else {
                        throw GatherError(.localized("err-sktn-xcode-def"))
                    }
                }
            case .spm:
                module = Module(spmArguments: buildToolArgs, spmName: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    throw GatherError(.localized("err-sktn-spm"))
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

private func inferBuildTool(in directory: URL, buildToolArgs: [String]) -> GatherBuildTool {
    #if os(macOS)
    guard directory.filesMatching("*.xcodeproj", "*.xcworkspace").isEmpty else {
        return .xcodebuild
    }

    guard !buildToolArgs.contains("-workspace"),
        !buildToolArgs.contains("-project") else {
        return .xcodebuild
    }
    #endif

    return .spm
}
