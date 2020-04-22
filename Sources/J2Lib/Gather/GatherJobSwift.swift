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
            default:
                preconditionFailure("Bad build tool for Swift source: \(actualBuildTool)")
            }

            logDebug(" Building ObjC translation table")
            let objcTranslation = GatherSwiftToObjC(module: module!)
            objcTranslation?.build()

            logDebug(" Calling sourcekitten docs generation")
            let filesInfo = module!.docs.compactMap { swiftDoc -> (String, GatherDef)? in
                logDebug(" Interpreting sourcekitten docs")
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

class GatherSwiftToObjC {
    private let module: Module
    private let objcHeaderPath: String

    struct Info {
        let name: String
        let declaration: String
    }

    private var usrToInfo = [String: Info]()

    /// Look up ObjC decl info from a USR
    func infoFrom(usr: String) -> Info? {
        usrToInfo[usr]
    }

    /// Look up ObjC decl info for a member with an @objc rename - we don't have
    /// the right USR so have to guess.
    func infoFrom(parentName: String, name: String) -> Info? {
        let pattern = #"@objc(cs)\(parentName)\(.*?\)\(name)$"#
        for item in usrToInfo {
            if item.key.re_isMatch(pattern) {
                return item.value
            }
        }
        return nil
    }

    private(set) var nameToInfo = [String: Info]()

    init?(module: Module) {
        self.module = module

        guard let emitOptIndex = module.compilerArguments.firstIndex(of: "-emit-objc-header-path"),
            case let pathIndex = emitOptIndex + 1,
            pathIndex < module.compilerArguments.count else {
            logDebug(" Build record has no sensible -emit-objc-header-path")
            return nil
        }

        objcHeaderPath = module.compilerArguments[pathIndex]

        guard FileManager.default.fileExists(atPath: objcHeaderPath) else {
            logWarning("Can't find Objective-C header file for \(module.name) at \(objcHeaderPath)")
            return nil
        }
        logDebug(" Found Obj-C header file \(objcHeaderPath)")
    }

    /// This is all gravy so we don't throw from here if things go wrong.
    #if os(macOS)
    func build() {
        let clangArgs = translateArgs()
        logDebug(" Invoking libclang with computed args:")
        clangArgs.forEach { logDebug("  \($0)") }
        let translationUnit = ClangTranslationUnit(headerFiles: [objcHeaderPath], compilerArguments: clangArgs)
        logDebug(" Found \(translationUnit.declarations.count) top-level declarations.")
    }
    #else
    func build() {}
    #endif

    func translateArgs() -> [String] {
        var copyNext = false
        var clangArgs = ["-x", "objective-c", "-fmodules"]
        for swiftArg in module.compilerArguments {
            if copyNext {
                if swiftArg.starts(with: "-") {
                    copyNext = false
                } else {
                    clangArgs.append(swiftArg)
                    continue
                }
            }
            guard swiftArg.starts(with: "-") else {
                continue
            }
            switch swiftArg {
            case "-sdk":
                clangArgs.append("-isysroot")
                copyNext = true

            case "-I", "-F", "-target", "-L":
                clangArgs.append(swiftArg)
                copyNext = true

            default:
                break
            }
        }
        return clangArgs
    }
}
