//
//  GatherSwiftToObjC.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// Generate ObjC names and declarations for a Swift module.
///
/// Fish out the bridging header and run it through libclang.
/// Then match its contents against Swift decls.
///
final class GatherSwiftToObjC: GatherDefVisitor {
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

    func visit(def: GatherDef, parents: [GatherDef]) throws {
    }
}
