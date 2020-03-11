//
//  GatherSourceKitten.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import SourceKittenFramework

typealias SourceKittenDict = [String: Any]

// Work around missing doc keys...

enum SwiftDocKey2: String {
    case fullyAnnotatedDecl = "key.fully_annotated_decl"
    case attributes = "key.attributes"
    case moduleName = "key.modulename"
    case accessibility = "key.accessibility"
    case overrides = "key.overrides"
}

// Specific getters

extension SourceKittenDict {
    private subscript(key: SwiftDocKey) -> Any? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }

    private subscript(key: SwiftDocKey2) -> Any? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }

    var name: String? {
        self[.name] as? String
    }

    var kind: String? {
        self[.kind] as? String
    }

    var documentationComment: String? {
        self[.documentationComment] as? String
    }

    var fullyAnnotatedDecl: String? {
        self[.fullyAnnotatedDecl] as? String
    }

    var parsedDeclaration: String? {
        self[.parsedDeclaration] as? String
    }

    var attributes: [SourceKittenDict]? {
        self[.attributes] as? [SourceKittenDict]
    }

    var moduleName: String? {
        self[.moduleName] as? String
    }

    var inheritedTypes: [SourceKittenDict]? {
        self[.inheritedtypes] as? [SourceKittenDict]
    }

    var offset: Int? {
        (self[.offset] as? Int64).flatMap(Int.init)
    }

    var length: Int? {
        (self[.length] as? Int64).flatMap(Int.init)
    }

    var swiftDeclaration: String? {
        self[SwiftDocKey.swiftDeclaration] as? String
    }

    var swiftName: String? {
        self[.swiftName] as? String
    }

    var diagnosticStage: String? {
        self[.diagnosticStage] as? String
    }

    var usr: String? {
        self[.usr] as? String
    }

    var typeName: String? {
        self[.typeName] as? String
    }

    var docLine: Int? {
        (self[.docLine] as? Int64).flatMap(Int.init)
    }

    var parsedScopeStart: Int? {
        (self[.parsedScopeStart] as? Int64).flatMap(Int.init)
    }

    var parsedScopeEnd: Int? {
        (self[.parsedScopeEnd] as? Int64).flatMap(Int.init)
    }

    var accessibility: String? {
        self[.accessibility] as? String
    }

    var overrides: [SourceKittenDict]? {
        self[.overrides] as? [SourceKittenDict]
    }

    var fullXMLDocs: String? {
        self[.fullXMLDocs] as? String
    }

    mutating func removeSubstructure() -> [SourceKittenDict] {
        removeValue(forKey: SwiftDocKey.substructure.rawValue) as? [SourceKittenDict] ?? []
    }
}
