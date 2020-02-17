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

    #if os(macOS)
    case objcDirect(moduleName: String,
                    headerFile: URL,
                    includePaths: [URL],
                    sdk: GatherOpts.Sdk,
                    buildToolArgs: [String],
                    availabilityRules: GatherAvailabilityRules)
    #endif

    func execute() throws -> [GatherModulePass] {
        logDebug("Gather: starting job \(self)")
        defer { logDebug("Gather: finished job") }

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
            let filesInfo = module!.docs.compactMap { swiftDoc -> (String, GatherDef)? in
                guard let def = GatherDef(sourceKittenDict: swiftDoc.docsDictionary,
                                          file: swiftDoc.file,
                                          availabilityRules: availabilityRules) else {
                    return nil
                }
                return (swiftDoc.file.path ?? "(no path)", def)
            }

            return [GatherModulePass(moduleName: module!.name, passIndex: 0, files: filesInfo)]
        #if os(macOS)
        case let .objcDirect(moduleName, headerFile, includePaths, sdk, buildToolArgs, availabilityRules):
            let clangArgs = ["-x", "objective-c", "-isysroot",
                             "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk",
                             "-fmodules"]
            logDebug(" Calling sourcekitten clang mode, args:")
            clangArgs.forEach { logDebug("  \($0)") }
            let translationUnit = ClangTranslationUnit(headerFiles: [headerFile.path], compilerArguments: clangArgs)
            logDebug(" Found \(translationUnit.declarations.count) top-level declarations.")
            let dicts = try JSON.decode(translationUnit.description, [[String: Any]].self)
            let filesInfo = try dicts.compactMap { dict -> (String, GatherDef)? in
                guard let dictEntry = dict.first,
                    dict.count == 1,
                    let fileDict = dictEntry.value as? SourceKittenDict else {
                    throw GatherError("Unexpected datashape from SourceKitten json, can't process dict '\(dict)'.")
                }
                guard let def = GatherDef(sourceKittenDict: fileDict, file: nil, availabilityRules: availabilityRules) else {
                    return nil
                }
                return (dictEntry.key, def)
            }
            return [GatherModulePass(moduleName: moduleName, passIndex: 0, files: filesInfo)]
        #endif
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
