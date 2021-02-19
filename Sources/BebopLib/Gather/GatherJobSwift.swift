//
//  GatherJobSwift.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
        let defOptions: Gather.DefOptions

        /// Invoke sourcekitten with stderr suppressed to stop spam when --quiet is set
        /// ...but still print out the error messages if thats what they turn out to be.
        func execute() throws -> GatherModulePass {
            StderrHusher.shared.hush()
            do {
                let result = try execute2()
                StderrHusher.shared.unhush()
                return result
            } catch {
                if let hushedStderr = StderrHusher.shared.unhush() {
                    logError(hushedStderr)
                }
                throw error
            }
        }

        private func execute2() throws -> GatherModulePass {
            let actualSrcDir = srcDir ?? FileManager.default.currentDirectory
            let actualBuildTool = buildTool ?? inferBuildTool(in: actualSrcDir, buildToolArgs: buildToolArgs)

            logDebug(" Using srcdir '\(actualSrcDir)', build tool '\(actualBuildTool)'")

            let module: Module!

            switch actualBuildTool {
            case .xcodebuild:
                logDebug(" Calling sourcekitten in swift xcodebuild mode")
                module = Module(xcodeBuildArguments: buildToolArgs, name: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    if let moduleName = moduleName {
                        throw BBError(.errSktnXcodeMod, moduleName)
                    }
                    throw BBError(.errSktnXcodeDef)
                }
            case .spm:
                logDebug(" Calling sourcekitten in swift spm mode")
                module = Module(spmArguments: buildToolArgs, spmName: moduleName, inPath: actualSrcDir.path)
                if module == nil {
                    throw BBError(.errSktnSpm)
                }
            default:
                preconditionFailure("Bad build tool for Swift source: \(actualBuildTool)")
            }

            logDebug(" Building ObjC translation table")
            let filesInfo = GatherSwiftToObjC.session(module: module) { () -> [(String, GatherDef)] in
                logDebug(" Calling sourcekitten docs generation")
                return module.docs.compactMap { swiftDoc -> (String, GatherDef)? in
                    guard let def = GatherDef(sourceKittenDict: swiftDoc.docsDictionary,
                                              file: swiftDoc.file,
                                              defOptions: defOptions) else {
                        return nil
                    }
                    return (swiftDoc.file.path ?? "(no path)", def)
                }
            }

            return GatherModulePass(moduleName: module!.name, files: filesInfo)
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
