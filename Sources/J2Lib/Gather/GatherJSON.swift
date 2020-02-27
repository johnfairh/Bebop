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

    /// Computed declaration, code string
    case swiftDeclaration = "key.j2.swift_declaration"
    case objCDeclaration = "key.j2.objc_declaration"
    /// Computed declaration messages, markdown string
    case swiftDeprecationMessage = "key.j2.swift_deprecation_messages"
    case objCDeprecationMessage = "key.j2.objc_deprecation_messages"
    case objCUnavailableMessage = "key.j2.objc_unavailable_messages"
    /// List of availability statements
    case availabilities = "key.j2.availabilities"
    case availability = "key.j2.availability"
    /// Name piece breakdown
    case swiftNamePieces = "key.j2.swift_name_pieces"
    case objCNamePieces = "key.j2.objc_name_pieces"
    case namePieceIsName = "key.j2.name_piece_is_name"
    case namePieceText = "key.j2.name_piece_text"
    /// Documentation
    case documentation = "key.j2.documentation"
    case abstract = "key.j2.abstract"
    case discussion = "key.j2.discussion"
    case returns = "key.j2.returns"
    case parameters = "key.j2.parameters"
    case paramName = "key.j2.param_name"
    case paramDesc = "key.j2.param_desc"
    /// Children
    case substructure = "key.substructure"
}

/// Helper to use `GatherKey`
fileprivate extension SourceKittenDict {
    mutating func set(_ key: GatherKey, _ value: Any) {
        self[key.rawValue] = value
    }
    mutating func maybe(_ key: GatherKey, _ value: Any?) {
        if let value = value {
            self[key.rawValue] = value
        }
    }
    mutating func maybe<T>(_ key: GatherKey, _ value: Array<T>) {
        if !value.isEmpty {
            self[key.rawValue] = value
        }
    }
}

fileprivate extension LocalizedDefDocs {
    var dictForJSON: SourceKittenDict {
        var dict = SourceKittenDict()
        dict.maybe(.abstract, abstract?.mapValues { $0.md })
        dict.maybe(.discussion, discussion?.mapValues { $0.md })
        dict.maybe(.returns, returns?.mapValues { $0.md })
        dict.maybe(.parameters, parameters.map { $0.dictForJSON })
        return dict
    }
}

fileprivate extension DefDocs.Param where T == Localized<Markdown> {
    var dictForJSON: SourceKittenDict {
        [GatherKey.paramName.rawValue : name,
         GatherKey.paramDesc.rawValue : description.mapValues { $0.md }]
    }
}

fileprivate extension Array where Element == DeclarationPiece {
    var dictsForJSON: [SourceKittenDict] {
        map {
            [GatherKey.namePieceIsName.rawValue: $0.isName,
             GatherKey.namePieceText.rawValue: $0.text]
        }
    }
}

extension GatherDef {
    /// Build up the dictionary from children and our garnished values
    var dictForJSON: SourceKittenDict {
        var dict = sourceKittenDict
        if let swiftDecl = swiftDeclaration {
            dict.set(.swiftDeclaration, swiftDecl.declaration)
            dict.maybe(.swiftDeprecationMessage, swiftDecl.deprecation)
            dict.maybe(.availabilities, swiftDecl.availability.map {
                [GatherKey.availability.rawValue : $0]
            })
            dict.maybe(.swiftNamePieces, swiftDecl.namePieces.dictsForJSON)
        }
        if let objCDecl = objCDeclaration {
            dict.set(.objCDeclaration, objCDecl.declaration)
            dict.maybe(.objCDeprecationMessage, objCDecl.deprecation)
            dict.maybe(.objCUnavailableMessage, objCDecl.unavailability)
            dict.maybe(.objCNamePieces, objCDecl.namePieces.dictsForJSON)
        }
        if !translatedDocs.isEmpty {
            dict.set(.documentation, translatedDocs.dictForJSON)
        }
        dict.maybe(.substructure, children.map { $0.dictForJSON })
        return dict
    }

    /// Add in extra metadata at the root
    func rootDictForJSON(moduleName: String, passIndex: Int) -> SourceKittenDict {
        var dict = dictForJSON
        dict.set(.version, Version.j2libVersion)
        dict.set(.moduleName, moduleName)
        dict.set(.passIndex, Int64(passIndex))
        return dict
    }
}

fileprivate extension GatherModulePass {
    /// Build array of 1-element hashes from pathname to data
    var dictsForJSON : [NSDictionary] {
        files.map { file in
            let contentsDict = file.1.rootDictForJSON(moduleName: moduleName, passIndex: passIndex)
            return toNSDictionary([file.pathname : contentsDict])
        }
    }
}

extension Array where Element == GatherModulePass {
    /// Accumulate the modules and convert
    public var json: String {
        let allFiles: [NSDictionary] = flatMap { $0.dictsForJSON}
        return SourceKittenFramework.toJSON(allFiles)
    }
}
