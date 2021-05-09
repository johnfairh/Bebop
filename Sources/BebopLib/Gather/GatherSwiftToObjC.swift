//
//  GatherSwiftToObjC.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// Generate ObjC names and declarations for a Swift module.
///
/// Fish out the bridging header and run it through libclang.
/// Build a table of usr -> {objc info}
/// Then `GatherDef.init(...)` and `SwiftObjCDeclarationBuilder` will query
/// the db when processing Swift decls.
///
final class GatherSwiftToObjC {
    private let module: Module
    private let objcHeaderPath: String

    struct Info {
        let name: String
        let declaration: String
    }

    private(set) var usrToInfo = [String: Info]()

    private init?(module: Module) {
        self.module = module

        guard let emitOptIndex = module.compilerArguments.firstIndex(of: "-emit-objc-header-path"),
            case let pathIndex = emitOptIndex + 1,
            pathIndex < module.compilerArguments.count else {
            logDebug(" Build record has no sensible -emit-objc-header-path")
            return nil
        }

        objcHeaderPath = module.compilerArguments[pathIndex]

        guard FileManager.default.fileExists(atPath: objcHeaderPath) else {
            logWarning(.wrnSw2objcHeader, module.name, objcHeaderPath)
            return nil
        }
        logDebug(" Found Obj-C header file \(objcHeaderPath)")
    }

    /// This is all gravy so we don't throw from here if things go wrong.
    #if os(macOS)
    private func build() {
        let clangArgs = translateArgs()
        logDebug(" Invoking libclang with computed args:")
        clangArgs.forEach { logDebug("  \($0)") }
        let translationUnit = ClangTranslationUnit(headerFiles: [objcHeaderPath], compilerArguments: clangArgs)
        logDebug(" Found \(translationUnit.declarations.count) top-level declarations.")
        try? translationUnit.asFiles().forEach { file in
            func process(dict: SourceKittenDict) {
                if let usr = dict.usr,
                    let parsedDeclaration = dict.parsedDeclaration,
                    let name = dict.name {
                    usrToInfo[usr] = Info(name: name, declaration: parsedDeclaration)
                }
                if let children = dict.substructure {
                    children.forEach { process(dict: $0) }
                }
            }
            process(dict: file.dict)
        }
    }
    #else
    func build() {}
    #endif

    /// Sketchily translate swift compiler args to clang.  Basically only accept stuff we understand.
    private func translateArgs() -> [String] {
        enum CopyNext {
            case no, ifRaw, yes
        }
        var copyNext = CopyNext.no
        var clangArgs = ["-x", "objective-c", "-fmodules"]
        for swiftArg in module.compilerArguments {
            if copyNext != .no {
                defer { copyNext = .no }
                if copyNext == .yes || (copyNext == .ifRaw && !swiftArg.starts(with: "-")) {
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
                copyNext = .yes

            case "-I", "-F", "-target", "-L":
                clangArgs.append(swiftArg)
                copyNext = .ifRaw

            case "-Xcc":
                copyNext = .yes

            default:
                break
            }
        }
        return clangArgs
    }

    // Session invocation.
    // This is so GatherDef can pick up any active translation session
    // from a deeply nested place without having to carry it around.

    static private(set) var current: GatherSwiftToObjC?

    static func session<T>(module: Module, run: () throws -> T) rethrows -> T {
        precondition(current == nil)
        defer { current = nil }
        current = GatherSwiftToObjC(module: module)
        current?.build()
        return try run()
    }
}
