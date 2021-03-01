//
//  GatherJobObjC.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
        let defOptions: Gather.DefOptions

        func execute() throws -> GatherModulePass {
            let clangArgs = try buildClangArgs()
            logDebug(" Calling sourcekitten clang mode, args:")
            clangArgs.forEach { logDebug("  \($0)") }
            let translationUnit = ClangTranslationUnit(headerFiles: [headerFile.path], compilerArguments: clangArgs)
            logDebug(" Found \(translationUnit.declarations.count) top-level declarations.")

            let filesInfo = try translationUnit.asFiles().compactMap { file -> (String, GatherDef)? in
                guard let def = GatherDef(sourceKittenDict: file.dict, defOptions: defOptions) else {
                     return nil
                }
                return (file.path, def)
            }
            return GatherModulePass(moduleName: moduleName, files: filesInfo)
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

            return ["-x", "objective-c", "-isysroot", try sdk.getPath(), "-fmodules"] + includePathArgs + buildToolArgs
        }

        /// Given a list of places where header files might be, churn out a list of include options that should
        /// cover attempts to use them.  Inherited from jazzy and stripped of the worst behaviours that cause
        /// clang to barf but I still don't love it.
        func buildIncludeArgs() throws -> [String] {
            let allDirURLs = try includePaths.map { baseURL -> Set<URL> in
                var dirPaths = Set([baseURL])
                guard let enumerator = FileManager.default.enumerator(atPath: baseURL.path) else {
                    throw BBError(.errEnumerator, baseURL.path)
                }
                while let pathname = enumerator.nextObject() as? String {
                    if pathname.re_isMatch(#"\.h(h|pp)?$"#) {
                        // Found a header file?  Add all directories from its directory up to
                        // the base - can't tell if "#import "a/b.h" etc.
                        var directoryURL = baseURL.appendingPathComponent(pathname).deletingLastPathComponent()
                        while !dirPaths.contains(directoryURL) {
                            dirPaths.insert(directoryURL)
                            directoryURL.deleteLastPathComponent()
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

#if os(macOS)

/// Pull out re-undecoding of the Clang JSON...
extension ClangTranslationUnit {
    struct File {
        let path: String
        let dict: SourceKittenDict
    }

    func asFiles() throws -> [File] {
        let dicts = try JSON.decode(description, [[String: Any]].self)
        return try dicts.map { dict in
            guard let dictEntry = dict.first,
                dict.count == 1,
                let fileDict = dictEntry.value as? SourceKittenDict else {
                throw BBError(.errObjcSourcekitten, dict)
            }
            return File(path: dictEntry.key, dict: fileDict)
        }
    }
}

#endif
