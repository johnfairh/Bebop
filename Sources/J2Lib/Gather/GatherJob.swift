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
    case swift(moduleName: String?,
               srcDir: URL?,
               buildTool: GatherOpts.BuildTool?,
               buildToolArgs: [String],
               availabilityRules: GatherAvailabilityRules)

    case objcDirect(moduleName: String,
                    srcDir: URL?,
                    headerFile: URL,
                    includePaths: [URL],
                    sdk: GatherOpts.Sdk,
                    buildToolArgs: [String],
                    availabilityRules: GatherAvailabilityRules)

    func execute() throws -> [GatherModulePass] {
        logDebug("Gather: starting job \(self)")
        defer { logDebug("Gather: finished job \(self)") }

        switch self {
        case let .swift(moduleName, srcDir, buildTool, buildToolArgs, availabilityRules):
            let actualSrcDir = srcDir ?? FileManager.default.currentDirectory
            let actualBuildTool = buildTool ?? inferBuildTool(in: actualSrcDir, buildToolArgs: buildToolArgs)

            logDebug(" Using srcdir '\(actualSrcDir)', build tool '\(actualBuildTool)'")

            let module: Module?

            switch actualBuildTool {
            case .xcodebuild:
                logDebug(" Calling sourcekitten in swift xcodebuild mode")
                module = Module(xcodeBuildArguments: buildToolArgs, name: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    if let moduleName = moduleName {
                        throw GatherError(.localized(.errSktnXcodeMod, moduleName))
                    }
                    throw GatherError(.localized(.errSktnXcodeDef))
                }
            case .spm:
                logDebug(" Calling sourcekitten in swift spm mode")
                module = Module(spmArguments: buildToolArgs, spmName: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    throw GatherError(.localized(.errSktnSpm))
                }
            }

            logDebug(" Calling sourcekitten docs generation")
            let filesInfo = module!.docs.map { swiftDoc in
                (swiftDoc.file.path ?? "(no path)",
                 GatherDef(sourceKittenDict: swiftDoc.docsDictionary, file: swiftDoc.file, availabilityRules: availabilityRules))
            }

            return [GatherModulePass(moduleName: module!.name, passIndex: 0, files: filesInfo)]

        case let .objcDirect(moduleName, srcDir, headerFile, includePaths, sdk, buildToolArgs, availabilityRules):
            return [GatherModulePass(moduleName: moduleName, passIndex: 0, files: [])]
        }
    }
}

private func inferBuildTool(in directory: URL, buildToolArgs: [String]) -> GatherOpts.BuildTool {
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
