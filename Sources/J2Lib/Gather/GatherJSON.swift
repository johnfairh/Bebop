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
//
// If Gather has done multiple passes then each pass contributes all its files.
// So if it does two passes over one module, we get two lots of files.

/// Keys added by J2.
private enum GatherKey: String {
    case version = "key.j2.version"         // metadata, root
    case passIndex = "key.j2.pass_index"    // metadata, root
    case moduleName = "key.j2.module_name"  // root-only
}

/// Helper to use `GatherKey`
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
    /// Build up the dictionary from children and our garnished values
    var dictForJSON: SourceKittenDict {
        var dict = sourceKittenDict
        if !children.isEmpty {
            dict[SwiftDocKey.substructure.rawValue] = children.map { $0.dictForJSON }
        }
        return dict
    }

    /// Add in extra metadata at the root
    func rootDictForJSON(moduleName: String, passIndex: Int) -> SourceKittenDict {
        var dict = dictForJSON
        dict[.version] = Version.j2libVersion
        dict[.moduleName] = moduleName
        dict[.passIndex] = Int64(passIndex)
        return dict
    }
}

extension GatherModulePass {
    /// Build array of 1-element hashes from pathname to data
    func dictsForJSON(moduleName: String) -> [NSDictionary] {
        defs.map { def in
            toNSDictionary([def.pathname : def.1.rootDictForJSON(moduleName: moduleName, passIndex: self.index)])
        }
    }
}

extension GatherModule {
    /// Accumulate the passes
    var dictsForJSON: [NSDictionary] {
        passes.flatMap { $0.dictsForJSON(moduleName: self.name) }
    }
}

extension GatherModules {
    /// Accumulate the modules and convert
    public var json: String {
        let allFiles: [NSDictionary] = modules.flatMap { $0.dictsForJSON }
        return toJSON(allFiles)
    }
}
