//
//  GatherJSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

// Decided to build on sourcekitten's existing JSON serialization logic for
// this phase, seeing as most of what we have is a `SourceKitten doc` tree and
// the idea is to be a superset of that output.
//
// So output is an array of mappings, one mapping per processed file, where each
// mapping has just one key, the pathname.  The value is the top-level SourceKit
// hash with `key.diagnostic_stage` and `key.substructure` for the contents.  We
// inject metadata keys at this top level and inject further data as we proceed
// down the Defs tree.

private enum GatherKey: String {
    case version = "key.j2.version"
    case moduleName = "key.j2.module_name"
    case passIndex = "key.j2.pass_index"
}

extension SourceKittenDict {
    fileprivate subscript(key: GatherKey) -> SourceKitRepresentable? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue
        }
    }
}

extension GatherDef {

    var dictForJSON: SourceKittenDict {
        sourceKittenDict
    }

    func rootDictForJSON(moduleName: String, passIndex: Int) -> SourceKittenDict {
        var dict = dictForJSON
        dict[.version] = Version.j2libVersion
        dict[.moduleName] = moduleName
        dict[.passIndex] = Int64(passIndex)
        return dict
    }
}

extension GatherModulePass {
    func dictsForJSON(moduleName: String) -> [NSDictionary] {
        defs.map { def in
            toNSDictionary([def.0 : def.1.rootDictForJSON(moduleName: moduleName, passIndex: self.index)])
        }
    }
}

extension GatherModule {
    var dictsForJSON: [NSDictionary] {
        passes.flatMap { $0.dictsForJSON(moduleName: self.name) }
    }
}

extension GatherModules {
    public var json: String {
        let allFiles: [NSDictionary] = modules.flatMap { $0.dictsForJSON }
        return toJSON(allFiles)
    }
}
