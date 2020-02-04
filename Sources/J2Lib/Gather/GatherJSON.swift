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

    /// Computed Swift declaration, code string
    case preferredDeclaration = "key.j2.preferred_swift_declaration"
    /// Computed declaration messages, markdown string
    case deprecationMessages = "key.j2.deprecation_messages"
    /// List of availability statements
    case availabilities = "key.j2.availabilities"
    case availability = "key.j2.availability"
    /// Name piece breakdown
    case namePieces = "key.j2.name_pieces"
    case namePieceIsName = "key.j2.name_piece_is_name"
    case namePieceText = "key.j2.name_piece_text"
    /// Documentation
    case documentation = "key.j2.documentation"
    case abstract = "key.j2.abstract"
    case overview = "key.j2.overview"
    case returns = "key.j2.returns"
    case parameters = "key.j2.parameters"
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

extension DefMarkdownDocs {
    var dictForJSON: SourceKittenDict {
        var dict = SourceKittenDict()
        if let abstract = abstract {
            dict[GatherKey.abstract] = abstract.description
        }
        if let overview = overview {
            dict[GatherKey.overview] = overview.description
        }
        if let returns = returns {
            dict[GatherKey.returns] = returns.description
        }
        if !parameters.isEmpty {
            dict[GatherKey.parameters] = parameters.mapValues { $0.description }
        }
        return dict
    }
}

extension GatherDef {
    /// Build up the dictionary from children and our garnished values
    var dictForJSON: SourceKittenDict {
        var dict = sourceKittenDict
        if let swiftDecl = swiftDeclaration {
            dict[.preferredDeclaration] = swiftDecl.declaration
            if !swiftDecl.deprecation.isEmpty {
                dict[.deprecationMessages] = swiftDecl.deprecation
            }
            if !swiftDecl.availability.isEmpty {
                dict[.availabilities] = swiftDecl.availability.map {
                    [GatherKey.availability.rawValue : $0]
                }
            }
            if !swiftDecl.namePieces.isEmpty {
                dict[.namePieces] = swiftDecl.namePieces.map { piece -> SourceKittenDict in
                    let isName: Bool
                    let text: String
                    switch piece {
                    case .name(let name):
                        isName = true
                        text = name
                    case .other(let other):
                        isName = false
                        text = other
                    }
                    return [GatherKey.namePieceIsName.rawValue: isName,
                            GatherKey.namePieceText.rawValue: text]
                }
            }
        }
        if !translatedDocs.isEmpty {
            dict[.documentation] = translatedDocs.mapValues { $0.dictForJSON }
        }
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
