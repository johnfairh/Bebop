//
//  GatherJobObjC.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

//
// Job to get info from an Objective C module via SourceKitten/LibClang
//
// macOS only to follow SourceKitten.
//

extension GatherJob {

    #if os(macOS)
    struct ObjCDirect: Equatable {
        let moduleName: String
        let headerFile: URL
        let includePaths: [URL]
        let sdk: Gather.Sdk
        let buildToolArgs: [String]
        let availability: Gather.Availability

        func execute() throws -> GatherModulePass {
            let clangArgs = try buildClangArgs()
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
                guard let def = GatherDef(sourceKittenDict: fileDict,
                                          parentNameComponents: [],
                                          file: nil,
                                          availability: availability) else {
                                            return nil
                }
                return (dictEntry.key, def)
            }
            return GatherModulePass(moduleName: moduleName, passIndex: 0, files: filesInfo)
        }

        /// Figure out the actual args to pass to clang given some options.  Visibility for testing.
        func buildClangArgs() throws -> [String] {
            let includePathArgs = try buildIncludeArgs()
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
        func buildIncludeArgs() throws -> [String] {
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

    #else
    /* !macOS compatibility */
    typealias ObjCDirect = Int
    #endif
}
