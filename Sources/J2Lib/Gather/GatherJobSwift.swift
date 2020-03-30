//
//  GatherJobSwift.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

//
// Job to get data from a Swift module source using SourceKitten/SourceKit
// SPM or xcodebuild.
//
extension GatherJob {
    struct Swift: Equatable {
        let moduleName: String?
        let srcDir: URL?
        let buildTool: Gather.BuildTool?
        let buildToolArgs: [String]
        let availability: Gather.Availability

        func execute() throws -> GatherModulePass {
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
            let filesInfo = module!.docs.compactMap { swiftDoc -> (String, GatherDef)? in
                guard let def = GatherDef(sourceKittenDict: swiftDoc.docsDictionary,
                                          parentNameComponents: [],
                                          file: swiftDoc.file,
                                          availability: availability) else {
                                            return nil
                }
                return (swiftDoc.file.path ?? "(no path)", def)
            }

            return GatherModulePass(moduleName: module!.name, passIndex: 0, imported: false, files: filesInfo)
        }
    }
}

private func inferBuildTool(in directory: URL, buildToolArgs: [String]) -> Gather.BuildTool {
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
