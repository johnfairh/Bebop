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
            let clangArgs = try buildClangArgs(includePaths: includePaths, sdk: sdk, buildToolArgs: buildToolArgs)
            logDebug(" Calling sourcekitten clang mode, args:")
            clangArgs.forEach { logDebug("  \($0)") }
            let translationUnit = ClangTranslationUnit(headerFiles: [headerFile.path], compilerArguments: clangArgs)
            logDebug(" Found \(translationUnit.declarations.count) top-level declarations.")
            let dicts = try JSON.decode(translationUnit.description, [[String: Any]].self)
            let filesInfo = try dicts.compactMap { dict -> (String, GatherDef)? in
                guard let dictEntry = dict.first,
                    dict.count == 1,
                    let fileDict = dictEntry.value as? SourceKittenDict else {
                    throw GatherError(.localized(.errObjcSourcekitten, dict))
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

    /// Figure out the actual args to pass to clang given some options.  Visibility for testing.
    func buildClangArgs(includePaths: [URL], sdk: GatherOpts.Sdk, buildToolArgs: [String]) throws -> [String] {
        let includePathArgs = try buildIncludeArgs(includePaths: includePaths)
        if buildToolArgs.count >= 2 &&
            buildToolArgs[0] == "-x" &&
            buildToolArgs[1] == "objective-c" {
            logDebug( "BuildToolArgs starts '-x objective-c', passing unchanged to clang")
            return buildToolArgs + includePathArgs
        }

        let sdkPathResults = Exec.run("/usr/bin/env", "xcrun", "--show-sdk-path", "--sdk", sdk.rawValue, stderr: .merge)
        guard let sdkPath = sdkPathResults.successString else {
            throw GatherError(.localized(.errObjcSdk) + "\n\(sdkPathResults.failureReport)")
        }
        return ["-x", "objective-c", "-isysroot", sdkPath, "-fmodules"] + includePathArgs + buildToolArgs
    }

    /// Given a list of places where header files might be, churn out a list of include options that should
    /// cover attempts to use them.  Inherited from jazzy and stripped of the worst behaviours that cause
    /// clang to barf but I still don't love it.
    func buildIncludeArgs(includePaths: [URL]) throws -> [String] {
        let allDirURLs = try includePaths.map { baseURL -> Set<URL> in
            var dirPaths = Set([baseURL])
            guard let enumerator = FileManager.default.enumerator(atPath: baseURL.path) else {
                throw GatherError(.localized(.errEnumerator, baseURL.path))
            }
            while let pathname = enumerator.nextObject() as? String {
                if pathname.re_isMatch(#"\.h(h|pp)?$"#) {
                    // Found a header file?  Add all directories from its directory up to
                    // the base - can't tell if "#import "a/b.h" etc.
                    var directoryURL = baseURL.appendingPathComponent(pathname).deletingLastPathComponent().standardized
                    while !dirPaths.contains(directoryURL) {
                        dirPaths.insert(directoryURL)
                        directoryURL.deleteLastPathComponent()
                        directoryURL.standardize()
                    }
                }
            }
            logDebug(" Expanded include path '\(baseURL.path)' to:")
            dirPaths.forEach { logDebug("  \($0.path)")}
            return dirPaths
        }

        return Array(allDirURLs.reduce(Set<URL>()) { $0.union($1) })
            // search from roots down
            .sorted(by: {$0.path.directoryNestingDepth < $1.path.directoryNestingDepth})
            .flatMap { ["-I", $0.path] }
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
