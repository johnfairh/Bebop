//
//  GatherJSON.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
//
//
// Rather came to regret this serialization approach when it came to
// deserializing it!  What a mess.  Rewrite next time I'm really ill.

/// Keys added by Bebop
private enum GatherKey: String {
    case version = "key.bb.version"         // metadata, root
    case passIndex = "key.bb.pass_index"    // metadata, root
    case moduleName = "key.bb.module_name"  // root-only

    /// Computed declaration, code string
    case swiftDeclaration = "key.bb.swift_declaration"
    case objCDeclaration = "key.bb.objc_declaration"
    /// Computed declaration messages, markdown string
    case swiftDeprecationMessage = "key.bb.swift_deprecation_messages"
    case swiftDeprecatedEverywhere = "key.bb.swift_deprecated_everywhere"
    case swiftUnavailabilityMessage = "key.bb.swift_unavailable_messages"
    case objCDeprecationMessage = "key.bb.objc_deprecation_messages"
    case objCUnavailableMessage = "key.bb.objc_unavailable_messages"
    /// List of availability statements
    case availabilities = "key.bb.availabilities"
    case availability = "key.bb.availability"
    /// Misc declaration facts
    case swiftTypeModuleName = "key.bb.type_module_name"
    case swiftInheritedTypes = "key.bb.inherited_types"
    case swiftInheritedTypeName = "key.bb.type_name"
    case swiftIsOverride = "key.bb.is_override"
    case swiftIsSPI = "key.bb.is_spi"
    /// Name piece breakdown
    case swiftNamePieces = "key.bb.swift_name_pieces"
    case objCNamePieces = "key.bb.objc_name_pieces"
    case namePieceIsName = "key.bb.name_piece_is_name"
    case namePieceText = "key.bb.name_piece_text"
    /// Documentation
    case documentation = "key.bb.documentation"
    case abstract = "key.bb.abstract"
    case discussion = "key.bb.discussion"
    case `throws` = "key.bb.throws"
    case returns = "key.bb.returns"
    case parameters = "key.bb.parameters"
    case paramName = "key.bb.param_name"
    case paramDesc = "key.bb.param_desc"
    case docSource = "key.bb.doc_source"
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
    mutating func remove(_ key: GatherKey) -> Any? {
        self.removeValue(forKey: key.rawValue)
    }
    func get(_ key: GatherKey) -> Any? {
        self[key.rawValue]
    }
}

extension SourceKittenDict {
    mutating func removeMetadata() -> (version: String, moduleName: String, pass: Int)? {
        guard let bebopVersion = remove(.version) as? String,
            let passIndex = remove(.passIndex) as? Int64,
            let moduleName = remove(.moduleName) as? String else {
                return nil
        }
        return (bebopVersion, moduleName, Int(passIndex))
    }
}

fileprivate extension LocalizedDefDocs {
    var dictForJSON: SourceKittenDict {
        var dict = SourceKittenDict()
        dict.maybe(.abstract, abstract?.mapValues { $0.value })
        dict.maybe(.discussion, discussion?.mapValues { $0.value })
        dict.maybe(.throws, `throws`?.mapValues { $0.value })
        dict.maybe(.returns, returns?.mapValues { $0.value })
        dict.maybe(.parameters, parameters.map { $0.dictForJSON })
        dict.set(.docSource, source.rawValue)
        return dict
    }

    init?(dict: SourceKittenDict) {
        self.abstract =
            (dict.get(.abstract) as? Localized<String>)?.mapValues { Markdown($0) }
        self.discussion =
            (dict.get(.discussion) as? Localized<String>)?.mapValues { Markdown($0) }
        self.throws =
            (dict.get(.throws) as? Localized<String>)?.mapValues { Markdown($0) }
        self.returns =
            (dict.get(.returns) as? Localized<String>)?.mapValues { Markdown($0) }
        self.parameters =
            (dict.get(.parameters) as? [SourceKittenDict])?.compactMap { Param(dict: $0) } ?? []
        self.defaultAbstract = nil
        self.defaultDiscussion = nil
        self.source = (dict.get(.docSource) as? String).flatMap { DefDocSource(rawValue: $0) } ?? .docComment
    }
}

fileprivate extension DefDocs.Param where T == Localized<Markdown> {
    var dictForJSON: SourceKittenDict {
        [GatherKey.paramName.rawValue : name,
         GatherKey.paramDesc.rawValue : description.mapValues { $0.value }]
    }

    init?(dict: SourceKittenDict) {
        guard let name = dict.get(.paramName) as? String,
            let desc = dict.get(.paramDesc) as? Localized<String> else {
                return nil
        }
        self.name = name
        self.description = desc.mapValues { Markdown($0) }
    }
}

fileprivate extension Array where Element == DeclarationPiece {
    var dictsForJSON: [SourceKittenDict] {
        map {
            [GatherKey.namePieceIsName.rawValue: $0.isName,
             GatherKey.namePieceText.rawValue: $0.text]
        }
    }

    init(dicts: [SourceKittenDict]) {
        self = dicts.compactMap { dict in
            guard let nameIsName = dict.get(.namePieceIsName) as? Bool,
                let text = dict.get(.namePieceText) as? String else {
                    return nil
            }
            return nameIsName ? .name(text) : .other(text)
        }
    }
}

fileprivate extension SwiftDeclaration {
    func addToJSON(dict: inout SourceKittenDict) {
        dict.set(.swiftDeclaration, declaration.text)
        dict.maybe(.swiftDeprecationMessage, deprecation)
        dict.set(.swiftDeprecatedEverywhere, isDeprecatedEverywhere)
        dict.maybe(.swiftUnavailabilityMessage, unavailability)
        dict.maybe(.availabilities, availability.map {
            [GatherKey.availability.rawValue : $0]
        })
        dict.maybe(.swiftNamePieces, namePieces.dictsForJSON)
        dict.maybe(.swiftTypeModuleName, typeModuleName)
        dict.maybe(.swiftInheritedTypes, inheritedTypes.map {
            [GatherKey.swiftInheritedTypeName.rawValue: $0]
        })
        dict.set(.swiftIsOverride, isOverride)
        dict.set(.swiftIsSPI, isSPI)
    }

    static func fromJSON(dict: inout SourceKittenDict) -> SwiftDeclaration? {
        guard let declarationText = dict.remove(.swiftDeclaration) as? String,
            let isOverride = dict.remove(.swiftIsOverride) as? Bool else {
            return nil
        }
        let deprecation = dict.remove(.swiftDeprecationMessage) as? Localized<String>
        let deprecatedEverywhere = dict.remove(.swiftDeprecatedEverywhere) as? Bool ?? false
        let unavailability = dict.remove(.swiftUnavailabilityMessage) as? Localized<String>
        var availability = [String]()
        if let availDicts = dict.remove(.availabilities) as? [SourceKittenDict] {
            availability = availDicts.compactMap { $0[GatherKey.availability.rawValue] as? String }
        }
        var namePieces = [DeclarationPiece]()
        if let piecesDicts = dict.remove(.swiftNamePieces) as? [SourceKittenDict] {
            namePieces = Array<DeclarationPiece>(dicts: piecesDicts)
        }
        let typeModule = dict.remove(.swiftTypeModuleName) as? String
        var inheritedTypes = [String]()
        if let inheritedDicts = dict.remove(.swiftInheritedTypes) as? [SourceKittenDict] {
            inheritedTypes = inheritedDicts.compactMap { $0[GatherKey.swiftInheritedTypeName.rawValue] as? String }
        }
        let isSPI = (dict.remove(.swiftIsSPI) as? Bool) ?? false

        return SwiftDeclaration(declaration: declarationText,
                                deprecation: deprecation,
                                deprecatedEverywhere: deprecatedEverywhere,
                                unavailability: unavailability,
                                availability: availability,
                                namePieces: namePieces,
                                typeModuleName: typeModule,
                                inheritedTypes: inheritedTypes,
                                isOverride: isOverride,
                                isSPI: isSPI)
    }
}

fileprivate extension ObjCDeclaration {
    func addToJSON(dict: inout SourceKittenDict) {
        dict.set(.objCDeclaration, declaration.text)
        dict.maybe(.objCDeprecationMessage, deprecation)
        dict.maybe(.objCUnavailableMessage, unavailability)
        dict.maybe(.objCNamePieces, namePieces.dictsForJSON)
    }

    static func fromJSON(dict: inout SourceKittenDict) -> ObjCDeclaration? {
        guard let declaration = dict.remove(.objCDeclaration) as? String else {
            return nil
        }
        let deprecation = dict.remove(.objCDeprecationMessage) as? Localized<String>
        let unavailability = dict.remove(.objCUnavailableMessage) as? Localized<String>
        var namePieces = [DeclarationPiece]()
        if let piecesDicts = dict.remove(.objCNamePieces) as? [SourceKittenDict] {
            namePieces = Array<DeclarationPiece>(dicts: piecesDicts)
        }

        return ObjCDeclaration(declaration: declaration,
                               deprecation: deprecation,
                               unavailability: unavailability,
                               namePieces: namePieces)
    }
}

extension GatherDef {
    /// Build up the dictionary from children and our garnished values
    var dictForJSON: SourceKittenDict {
        var dict = sourceKittenDict
        swiftDeclaration?.addToJSON(dict: &dict)
        objCDeclaration?.addToJSON(dict: &dict)
        if !translatedDocs.isEmpty {
            dict.set(.documentation, translatedDocs.dictForJSON)
        }
        dict.maybe(.substructure, children.map { $0.dictForJSON })
        return dict
    }

    /// Add in extra metadata at the root
    func rootDictForJSON(moduleName: String, passIndex: Int) -> SourceKittenDict {
        var dict = dictForJSON
        dict.set(.version, Version.bebopLibVersion)
        dict.set(.moduleName, moduleName)
        dict.set(.passIndex, Int64(passIndex))
        return dict
    }

    /// Reconstitute a `GatherDef` from a dict (without any root stuff)
    convenience init(filesDict: SourceKittenDict) {
        var dict = filesDict
        var children = [GatherDef]()
        if let dictChildren = dict.remove(.substructure) as? [SourceKittenDict] {
            children = dictChildren.compactMap { GatherDef(filesDict: $0) }
        }
        let kind = dict.kind.flatMap { DefKind.from(key: $0) }
        let swiftDeclaration = SwiftDeclaration.fromJSON(dict: &dict)
        let objCDeclaration = ObjCDeclaration.fromJSON(dict: &dict)
        var translatedDocs: LocalizedDefDocs?
        if let docsDict = dict.remove(.documentation) as? SourceKittenDict {
            translatedDocs = LocalizedDefDocs(dict: docsDict)
        }
        Stats.inc(.gatherDefImport)
        self.init(children: children,
                  sourceKittenDict: dict,
                  kind: kind,
                  swiftDeclaration: swiftDeclaration,
                  objCDeclaration: objCDeclaration,
                  documentation: nil,
                  localizationKey: nil,
                  translatedDocs: translatedDocs)
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
        SourceKittenFramework.toJSON(flatMap { $0.dictsForJSON })
    }
}
