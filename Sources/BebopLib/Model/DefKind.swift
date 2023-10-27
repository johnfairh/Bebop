//
//  Kind.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

//
// Port and extension of SourceDeclaration::Type -- what are the different types
// of definition that can occur and how are they expressed in various envirnoments.
//

/// The type of a definition
public final class DefKind: CustomStringConvertible {
    /// The underlying key
    private let kindKey: Key
    /// The sourcekit[ten] key for the definition type
    public var key: String { kindKey.primary }
    /// Is this a Swift definition kind?
    public var isSwift: Bool { kindKey.isSwift }
    /// Is this an ObjC definition kind?
    public var isObjC: Bool { kindKey.isObjC }
    /// The metakind for the definition type
    public let metaKind: ItemKind
    /// The topic for the definition type
    public let defTopic: DefTopic
    /// The name of the declaration type per Dash rules, revised Jan 2020
    /// (https://kapeli.com/docsets#supportedentrytypes))
    public let dashName: String
    /// The keywords that should precede the declaration name
    public let declPrefix: String?

    /// The underlying sourcekitten key
    private struct Key {
        let primary: String
        let secondary: String?
        let isSwift: Bool

        var isObjC: Bool {
            !isSwift
        }

        private init(primary: String, secondary: String?, isSwift: Bool ) {
            self.primary = primary
            self.secondary = secondary
            self.isSwift = isSwift
        }

        init(swift: DeclarationKind, objc: DeclarationKind?) {
            self.init(primary: swift.rawValue, secondary: objc?.rawValue, isSwift: true)
        }

        init(objc: DeclarationKind, swift: DeclarationKind?) {
            self.init(primary: objc.rawValue, secondary: swift?.rawValue, isSwift: false)
        }
    }

    private init(_ kindKey: Key,
                 dashName: String = "",
                 declPrefix: String? = nil,
                 metaKind: ItemKind = .other,
                 defTopic: DefTopic = .other) {
        self.kindKey = kindKey
        self.dashName = dashName
        self.declPrefix = declPrefix
        self.metaKind = metaKind
        self.defTopic = defTopic
    }

    // These convenience inits are to make the big tables work properly.  The compiler has a nightmare
    // with them -- too much overloading, optional params, etc I guess -- to the point of never finishing
    // if I reduce the duplication much more.
    //
    // Now we know the actual requirements could be worth revisiting from scratch, maybe move into a
    // resource file?  Or model a pure abstract world with projections from there into Swift/ObjC?

    private convenience init(o key: ObjCDeclarationKind,
                             s swiftKey: SwiftDeclarationKind? = nil,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(objc: key, swift: swiftKey),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    private convenience init(o key: ObjCDeclarationKind2,
                             s swiftKey: SwiftDeclarationKind? = nil,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(objc: key, swift: swiftKey),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    private convenience init(s key: SwiftDeclarationKind,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(swift: key, objc: nil),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    private convenience init(s key: SwiftDeclarationKind,
                             o objcKey: ObjCDeclarationKind,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(swift: key, objc: objcKey),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    private convenience init(s key: SwiftDeclarationKind,
                             o objcKey: ObjCDeclarationKind2,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(swift: key, objc: objcKey),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    private convenience init(s key: SwiftDeclarationKind2,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(Key(swift: key, objc: nil),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    public var description: String {
        key.description
    }

    /// Map this kind into the other language.
    /// We may already have a declaration string in the other language that can adjust the kind.
    public func otherLanguageKind(otherLanguageDecl: String? = nil) -> DefKind? {
        // objc enums are imported as structs without NS_ENUM magic
        if isObjC,
            let swiftDecl = otherLanguageDecl,
            swiftDecl.hasPrefix("struct") {
            return DefKind.from(kind: SwiftDeclarationKind.struct)
        }
        return kindKey.secondary.flatMap { DefKind.from(key: $0) }
    }

    // MARK: Predicates

    private func testSwiftKey(keys: [SwiftDeclarationKind]) -> Bool {
        testKey(keys: keys)
    }

    private func testObjCKey(keys: [ObjCDeclarationKind]) -> Bool {
        testKey(keys: keys)
    }

    private func testKey(keys: [DeclarationKind]) -> Bool {
        return keys.lazy.map { $0.rawValue }.contains(key)
    }

    /// Is this def kind supposed to make it into docs?
    public var includeInDocs: Bool {
        !testObjCKey(keys: [.moduleImport]) && !testSwiftKey(keys: [.varParameter])
    }

    /// Is this some kind of extension or category?
    public var isExtension: Bool {
        isSwiftExtension || isObjCCategory
    }

    /// Is this any kind of Swift extension declaration?
    public var isSwiftExtension: Bool {
        testSwiftKey(keys: [
            .extension,
            .extensionClass,
            .extensionEnum,
            .extensionStruct,
            .extensionProtocol
        ])
    }

    /// Is this any kind of Swift property declaration?
    public var isSwiftProperty: Bool {
        testSwiftKey(keys: [
            .varClass,
            .varGlobal,
            .varLocal,
            .varStatic,
            .varInstance,
            .varParameter
        ])
    }

    /// Does this have a multipart function-like name?  `func` `init` `subscript`.
    public var hasSwiftFunctionName: Bool {
        testSwiftKey(keys: [
            .functionFree,
            .functionMethodClass,
            .functionMethodStatic,
            .functionMethodInstance,
            .functionConstructor
        ]) || isSwiftSubscript || isSwiftOperator
    }

    /// Is it a Swift operator?
    public var isSwiftOperator: Bool {
        testSwiftKey(keys: [
            .functionOperator,
            .functionOperatorPostfix,
            .functionOperatorPrefix,
            .functionOperatorInfix
        ])
    }

    /// EnumCase is the useless wrapper, we usually want the enumelement[s] within
    public var isSwiftEnumCase: Bool {
        testSwiftKey(keys: [.enumcase])
    }

    /// EnumElement is the singular enum element
    public var isSwiftEnumElement: Bool {
        testSwiftKey(keys: [.enumelement])
    }

    /// Is it a Swift protocol?
    public var isSwiftProtocol: Bool {
        testSwiftKey(keys: [.protocol])
    }

    /// Is it a Swift subscript?
    public var isSwiftSubscript: Bool {
        testKey(keys: [
            SwiftDeclarationKind.functionSubscript,
            SwiftDeclarationKind2.functionSubscriptClass,
            SwiftDeclarationKind2.functionSubscriptStatic
        ])
    }

    /// Is it a Swift class?
    public var isSwiftClass: Bool {
        testSwiftKey(keys: [.class])
    }

    /// Is it a Swift nominal type _with a body_?
    public var isSwiftBodiedType: Bool {
        testKey(keys: [
            SwiftDeclarationKind.class,
            SwiftDeclarationKind.protocol,
            SwiftDeclarationKind.struct,
            SwiftDeclarationKind.enum,
            SwiftDeclarationKind.actor]) || isSwiftExtension
    }

    /// Is this a generic type parameter (The T in `class N<T>`)
    public var isGenericParameter: Bool {
        testSwiftKey(keys: [.genericTypeParam])
    }

    /// Is this a mark -- an objC `#pragma mark` or a Swift // MARK: - like comment
    public var isMark: Bool {
        testKey(keys: [SwiftDeclarationKind2.sourceMark,
                       ObjCDeclarationKind.mark])
    }

    /// Is this an ObjC decl with a 'body' - like struct or @interface
    public var isObjCStructural: Bool {
        testObjCKey(keys: [
            .category,
            .class,
            .enum,
            .protocol,
            .struct,
        ])
    }

    /// Is this a typedef
    public var isObjCTypedef: Bool {
        testObjCKey(keys: [.typedef])
    }

    /// Is this a @property
    public var isObjCProperty: Bool {
        testKey(keys: [
            ObjCDeclarationKind.property,
            ObjCDeclarationKind2.propertyClass
        ])
    }

    /// Is this a thing with method syntax
    public var isObjCMethod: Bool {
        testObjCKey(keys: [
            .initializer,
            .methodClass,
            .methodInstance
        ])
    }

    /// Is a raw C function with C syntax
    public var isObjCCFunction: Bool {
        testObjCKey(keys: [.function])
    }

    /// Is basically a C variable
    public var isObjCVariable: Bool {
        testObjCKey(keys: [
            .constant,
            .field,
            .ivar
        ]) || isObjCProperty
    }

    /// Is it an ObjC category
    public var isObjCCategory: Bool {
        testObjCKey(keys: [.category])
    }

    // MARK: Factory

    /// Find the `Kind` object from a sourcekitten dictionary key, or `nil` if it's not supported
    static func from(key: String) -> DefKind? {
        kindMap[key]
    }

    /// Find the `DefKind` from an element of one of the kind enums
    static func from(kind: DeclarationKind) -> DefKind {
        kindMap[kind.rawValue]!
    }

    /// Cache string -> Kind
    private static let kindMap: [String : DefKind] = {
        var map: [String: DefKind] = [:]
        allSwiftKinds.forEach { map[$0.key] = $0 }
        allObjCKinds.forEach { map[$0.key] = $0 }
        return map
    }()

    /// Master list of kinds.  I've superstitiously kept the jazzy ordering, which might affect the default
    /// ordering somewhere - tbd.

    private static let allObjCKinds: [DefKind] = [
        // Objective-C
        DefKind(o: .unexposedDecl,                              dash: "Type"),
        DefKind(o: .category,       s: .extension,              dash: "Extension", dp: "@interface", meta: .extension),
        DefKind(o: .class,          s: .class,                  dash: "Class",     dp: "@interface", meta: .type),
        DefKind(o: .constant,       s: .varGlobal,              dash: "Constant",                    meta: .variable),
        DefKind(o: .enum,           s: .enum, /* or struct */   dash: "Enum",      dp: "enum",       meta: .type),
        DefKind(o: .enumcase,       s: .enumelement,            dash: "Case",      dp: "",                             tpc: .enumElement),
        DefKind(o: .initializer,    s: .functionConstructor,    dash: "Initializer",                                   tpc: .initializer),
        DefKind(o: .methodClass,    s: .functionMethodClass,    dash: "Method",                                        tpc: .classMethod),
        DefKind(o: .methodInstance, s: .functionMethodInstance, dash: "Method",                                        tpc: .method),
        DefKind(o: .property,       s: .varInstance,            dash: "Property",                                      tpc: .property),
        DefKind(o: .propertyClass,  s: .varClass,               dash: "Property",                                      tpc: .classProperty),
        DefKind(o: .protocol,       s: .protocol,               dash: "Protocol",  dp: "@protocol",  meta: .type),
        DefKind(o: .typedef,        s: .typealias,              dash: "Type",      dp: "typedef",    meta: .type),
        DefKind(o: .function,       s: .functionFree,           dash: "Function",                    meta: .function),
        DefKind(o: .struct,         s: .struct,                 dash: "Struct",    dp: "struct",     meta: .type),
        DefKind(o: .field,          s: .varInstance,            dash: "Field",                                         tpc: .field),
        DefKind(o: .ivar,                                       dash: "Variable",                                      tpc: .field),
        DefKind(o: .mark),
        DefKind(o: .moduleImport)
    ]

    private static let allSwiftKinds: [DefKind] = [
        // Swift
        // Most of these are inaccessible - generated by other parts of SourceKit (or not
        // at all) or filtered out before we think about documenting them, but it's easier
        // to just list them all.
        DefKind(s: .functionAccessorAddress,                            dash: "Function"),
        DefKind(s: .functionAccessorDidset,                             dash: "Function"),
        DefKind(s: .functionAccessorGetter,                             dash: "Function"),
        DefKind(s: .functionAccessorMutableaddress,                     dash: "Function"),
        DefKind(s: .functionAccessorSetter,                             dash: "Function"),
        DefKind(s: .functionAccessorWillset,                            dash: "Function"),
        DefKind(s: .functionAccessorRead,                               dash: "Function"),
        DefKind(s: .functionAccessorModify,                             dash: "Function"),
        DefKind(s: .functionOperator,                                   dash: "Function",    dp: "static func",    meta: .operator,   tpc: .operator),
        DefKind(s: .functionOperatorInfix,                              dash: "Function"),
        DefKind(s: .functionOperatorPostfix,                            dash: "Function"),
        DefKind(s: .functionOperatorPrefix,                             dash: "Function"),
        DefKind(s: .functionMethodClass,            o: .methodClass,    dash: "Method",      dp: "class func",                        tpc: .classMethod),
        DefKind(s: .varClass,                       o: .propertyClass,  dash: "Property",    dp: "class var",                         tpc: .classProperty),
        DefKind(s: .class,                          o: .class,          dash: "Class",       dp: "class",          meta: .type,       tpc: .type),
        DefKind(s: .functionConstructor,            o: .initializer,    dash: "Constructor",                                          tpc: .initializer),
        DefKind(s: .functionDestructor,                                 dash: "Method",                                               tpc: .deinitializer),
        DefKind(s: .varGlobal,                      o: .constant,       dash: "Global",      dp: "var",            meta: .variable),
        DefKind(s: .enumcase,                                           dash: "Case",        dp: "case",                              tpc: .enumElement),
        DefKind(s: .enumelement,                    o: .enumcase,       dash: "Case",        dp: "case",                              tpc: .enumElement),
        DefKind(s: .enum,                           o: .enum,           dash: "enum",        dp: "enum",           meta: .type,       tpc: .type),
        DefKind(s: .extension,                      o: .category,       dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionClass,                                     dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionEnum,                                      dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionProtocol,                                  dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionStruct,                                    dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .functionFree,                   o: .function,       dash: "Global",      dp: "func",           meta: .function),
        DefKind(s: .functionMethodInstance,         o: .methodInstance, dash: "Method",      dp: "func",                              tpc: .method),
        DefKind(s: .varInstance,                    o: .property,       dash: "Property",    dp: "var",                               tpc: .property),
        DefKind(s: .varLocal,                                           dash: "Variable",    dp: "var"),
        DefKind(s: .varParameter,                                       dash: "Parameter"),
        DefKind(s: .protocol,                       o: .protocol,       dash: "Protocol",    dp: "protocol",       meta: .type,       tpc: .type),
        DefKind(s: .functionMethodStatic,           o: .methodClass,    dash: "Method",      dp: "static func",                       tpc: .staticMethod),
        DefKind(s: .varStatic,                      o: .propertyClass,  dash: "Variable",    dp: "static var",                        tpc: .staticProperty),
        DefKind(s: .struct,                         o: .struct,         dash: "Struct",      dp: "struct",         meta: .type,       tpc: .type),
        DefKind(s: .functionSubscript,                                  dash: "Method",                                               tpc: .subscript),
        DefKind(s: .functionSubscriptClass,                             dash: "Method",      dp: "class",                             tpc: .classSubscript),
        DefKind(s: .functionSubscriptStatic,                            dash: "Method",      dp: "static",                            tpc: .staticSubscript),
        DefKind(s: .typealias,                      o: .typedef,        dash: "Alias",       dp: "typealias",      meta: .type,       tpc: .type),
        DefKind(s: .genericTypeParam,                                   dash: "Parameter"),
        DefKind(s: .associatedtype,                                     dash: "Type",        dp: "associatedtype",                    tpc: .associatedType),
        DefKind(s: .opaqueType,                                         dash: "Type"),
        DefKind(s: .module,                                             dash: "Module"),
        DefKind(s: .precedenceGroup,                                    dash: "Type",        dp: "precedencegroup"),
        DefKind(s: .sourceMark),
        DefKind(s: .actor,                                              dash: "Actor",       dp: "actor",          meta: .type,       tpc: .type)
    ]
}

extension DefKind: Equatable {
    public static func == (lhs: DefKind, rhs: DefKind) -> Bool {
        lhs.key == rhs.key
    }
}
