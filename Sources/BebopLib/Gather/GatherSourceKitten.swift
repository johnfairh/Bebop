//
//  GatherSourceKitten.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import SourceKittenFramework

public typealias SourceKittenDict = [String: Any]

// MARK: Missing Doc Keys and Kinds

enum SwiftDocKey2: String {
    case annotatedDecl = "key.annotated_decl"
    case fullyAnnotatedDecl = "key.fully_annotated_decl"
    case attributes = "key.attributes"
    case moduleName = "key.modulename"
    case accessibility = "key.accessibility"
    case overrides = "key.overrides"
    case inheritedDocs = "key.inherited_docs"
    case objcName = "key.objc_name"
}

enum SwiftDeclarationKind2: String {
    case functionSubscriptStatic = "source.lang.swift.decl.function.subscript.static"
    case functionSubscriptClass = "source.lang.swift.decl.function.subscript.class"
    case sourceMark = "source.lang.swift.syntaxtype.comment.mark"
}

enum ObjCDeclarationKind2: String {
    case propertyClass = "sourcekitten.source.lang.objc.decl.property.class"
}

/// Marker protocol for all enums that define known keys
protocol DeclarationKind {
    var rawValue: String { get }
}

extension SwiftDeclarationKind: DeclarationKind {}
extension SwiftDeclarationKind2: DeclarationKind {}
extension ObjCDeclarationKind: DeclarationKind {}
extension ObjCDeclarationKind2: DeclarationKind {}

// MARK: Typed Dict Getters

extension SourceKittenDict {
    subscript(key: SwiftDocKey) -> Any? {
        get { self[key.rawValue] }
        set { if let newValue = newValue { self[key.rawValue] = newValue } }
    }

    subscript(key: SwiftDocKey2) -> Any? {
        get { self[key.rawValue] }
        set { if let newValue = newValue { self[key.rawValue] = newValue } }
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

    var annotatedDecl: String? {
        self[.annotatedDecl] as? String
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

    var docDeclaration: String? {
        self[.docDeclaration] as? String
    }

    var filePath: String? {
        self[.filePath] as? String
    }

    var inheritedDocs: Bool? {
        self[.inheritedDocs] as? Bool
    }

    var substructure: [SourceKittenDict]? {
        self[.substructure] as? [SourceKittenDict]
    }

    var objcName: String? {
        self[.objcName] as? String
    }

    mutating func removeSubstructure() -> [SourceKittenDict] {
        removeValue(forKey: SwiftDocKey.substructure.rawValue) as? [SourceKittenDict] ?? []
    }
}

// MARK: Linux

#if os(Linux) /* Too exhausting to chop out references to these */
public enum ObjCDeclarationKind: String {
    /// `category`.
    case category = "sourcekitten.source.lang.objc.decl.category"
    /// `class`.
    case `class` = "sourcekitten.source.lang.objc.decl.class"
    /// `constant`.
    case constant = "sourcekitten.source.lang.objc.decl.constant"
    /// `enum`.
    case `enum` = "sourcekitten.source.lang.objc.decl.enum"
    /// `enumcase`.
    case enumcase = "sourcekitten.source.lang.objc.decl.enumcase"
    /// `initializer`.
    case initializer = "sourcekitten.source.lang.objc.decl.initializer"
    /// `method.class`.
    case methodClass = "sourcekitten.source.lang.objc.decl.method.class"
    /// `method.instance`.
    case methodInstance = "sourcekitten.source.lang.objc.decl.method.instance"
    /// `property`.
    case property = "sourcekitten.source.lang.objc.decl.property"
    /// `protocol`.
    case `protocol` = "sourcekitten.source.lang.objc.decl.protocol"
    /// `typedef`.
    case typedef = "sourcekitten.source.lang.objc.decl.typedef"
    /// `function`.
    case function = "sourcekitten.source.lang.objc.decl.function"
    /// `mark`.
    case mark = "sourcekitten.source.lang.objc.mark"
    /// `struct`
    case `struct` = "sourcekitten.source.lang.objc.decl.struct"
    /// `field`
    case field = "sourcekitten.source.lang.objc.decl.field"
    /// `ivar`
    case ivar = "sourcekitten.source.lang.objc.decl.ivar"
    /// `ModuleImport`
    case moduleImport = "sourcekitten.source.lang.objc.module.import"
    /// `UnexposedDecl`
    case unexposedDecl = "sourcekitten.source.lang.objc.decl.unexposed"
}
#endif
