//
//  Kind.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
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
    public var key: String { kindKey.key }
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

    /// The underlying sourcekitten key - keep hold of the enum to avoid string comparisons (right?)
    private enum Key: CustomStringConvertible {
        case swift(SwiftDeclarationKind)
        case objC(ObjCDeclarationKind, SwiftDeclarationKind?)
        // Only for swift 'MARK' comments rn...
        case other(key: String, isSwift: Bool)

        var isSwift: Bool {
            switch self {
            case .swift(_): return true;
            case .objC(_, _): return false;
            case .other(_, let isSwift): return isSwift;
            }
        }

        var isObjC: Bool {
            switch self {
            case .swift(_): return false;
            case .objC(_, _): return true;
            case .other(_, let isSwift): return !isSwift;
            }
        }

        var key: String {
            switch self {
            case .swift(let kind): return kind.rawValue
            case .objC(let kind, _): return kind.rawValue
            case .other(let key, _): return key
            }
        }

        var description: String { key }
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

    private convenience init(o key: ObjCDeclarationKind,
                             s swiftKey: SwiftDeclarationKind? = nil,
                             dash: String = "",
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other,
                             tpc defTopic: DefTopic = .other) {
        self.init(.objC(key, swiftKey),
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
        self.init(.swift(key),
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind,
                  defTopic: defTopic)
    }

    public var description: String {
        key.description
    }

    /// Map this kind into the other language.  Currently only maps objc -> swift.
    var otherLanguageKind: DefKind? {
        guard case let .objC(_, swiftKey) = kindKey else {
            return nil
        }
        return swiftKey.flatMap { DefKind.from(key: $0.rawValue) }
    }

    // MARK: Predicates

    private func testSwiftKey(keys: [SwiftDeclarationKind]) -> Bool {
        guard case let .swift(swiftKey) = kindKey else {
            return false
        }
        return keys.contains(swiftKey)
    }

    private func testObjCKey(keys: [ObjCDeclarationKind]) -> Bool {
        guard case let .objC(objcKey, _) = kindKey else {
            return false
        }
        return keys.contains(objcKey)
    }

    /// Is this def kind supposed to make it into docs?
    var includeInDocs: Bool {
        !testObjCKey(keys: [.moduleImport])
    }

    /// Is this some kind of extension or category?
    var isExtension: Bool {
        isSwiftExtension || isObjCCategory
    }

    /// Is this any kind of Swift extension declaration?
    var isSwiftExtension: Bool {
        testSwiftKey(keys: [
            .extension,
            .extensionClass,
            .extensionEnum,
            .extensionStruct,
            .extensionProtocol
        ])
    }

    /// Is this any kind of Swift property declaration?
    var isSwiftProperty: Bool {
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
    var hasSwiftFunctionName: Bool {
        testSwiftKey(keys: [
            .functionFree,
            .functionOperator,
            .functionMethodClass,
            .functionMethodStatic,
            .functionMethodInstance,
            .functionSubscript,
            .functionConstructor
        ])
    }

    /// EnumCase is the useless wrapper, we usually want the enumelement[s] within
    var isSwiftEnumCase: Bool {
        testSwiftKey(keys: [.enumcase])
    }

    /// EnumElement is the singular enum element
    var isSwiftEnumElement: Bool {
        testSwiftKey(keys: [.enumelement])
    }

    /// Is it a Swift protocol?
    var isSwiftProtocol: Bool {
        testSwiftKey(keys: [.protocol])
    }

    /// Is this a generic type parameter (The T in `class N<T>`)
    var isGenericParameter: Bool {
        testSwiftKey(keys: [.genericTypeParam])
    }

    /// Is this a mark -- an objC `#pragma mark` or a Swift // MARK: - like comment
    var isMark: Bool {
        if case .other(_) = kindKey {
            return true
        }
        if case let .objC(k, _) = kindKey {
            return k == .mark
        }
        return false
    }

    /// Is this an ObjC decl with a 'body' - like struct or @interface
    var isObjCStructural: Bool {
        testObjCKey(keys: [
            .category,
            .class,
            .enum,
            .protocol,
            .struct,
        ])
    }

    /// Is this a typedef
    var isObjCTypedef: Bool {
        testObjCKey(keys: [.typedef])
    }

    /// Is this a @property
    var isObjCProperty: Bool {
        testObjCKey(keys: [.property])
    }

    /// Is this a thing with method syntax
    var isObjCMethod: Bool {
        testObjCKey(keys: [
            .initializer,
            .methodClass,
            .methodInstance
        ])
    }

    /// Is a raw C function with C syntax
    var isObjCCFunction: Bool {
        testObjCKey(keys: [.function])
    }

    /// Is basically a C variable
    var isObjCVariable: Bool {
        testObjCKey(keys: [
            .constant,
            .property,
            .field,
            .ivar
        ])
    }

    /// Is it an ObjC category
    var isObjCCategory: Bool {
        testObjCKey(keys: [.category])
    }

    // MARK: Factory

    /// Find the `Kind` object from a sourcekitten dictionary key, or `nil` if it's not supported
    public static func from(key: String) -> DefKind? {
        return kindMap[key]
    }

    /// Find the `Kind` object from a sourcekitten dictionary key and declaration name, or `nil` if it's not supported
    public static func from(key: String, name: String) -> DefKind? {
        kindMap[key].flatMap { $0.adjust(name: name) }
    }

    /// Cache string -> Kind
    private static let kindMap: [String : DefKind] = {
        var map: [String: DefKind] = [:]
        allSwiftKinds.forEach { map[$0.key] = $0 }
        allObjCKinds.forEach { map[$0.key] = $0 }
        return map
    }()

    /// Tweak cockups...
    private func adjust(name: String) -> DefKind {
        if hasSwiftFunctionName {
            if name.re_isMatch(#"^init[?!]?\("#) {
                return DefKind.from(key: SwiftDeclarationKind.functionConstructor.rawValue)!
            }
            if name == "deinit" {
                return DefKind.from(key: SwiftDeclarationKind.functionDestructor.rawValue)!
            }
        }
        return self
    }

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
        DefKind(o: .property,       s: .varInstance,/* or cls */dash: "Property",                                      tpc: .property),
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
        DefKind(s: .functionAccessorAddress,        dash: "Function"),
        DefKind(s: .functionAccessorDidset,         dash: "Function"),
        DefKind(s: .functionAccessorGetter,         dash: "Function"),
        DefKind(s: .functionAccessorMutableaddress, dash: "Function"),
        DefKind(s: .functionAccessorSetter,         dash: "Function"),
        DefKind(s: .functionAccessorWillset,        dash: "Function"),
        DefKind(s: .functionAccessorRead,           dash: "Function"),
        DefKind(s: .functionAccessorModify,         dash: "Function"),
        DefKind(s: .functionOperatorInfix,          dash: "Function"),
        DefKind(s: .functionOperatorPostfix,        dash: "Function"),
        DefKind(s: .functionOperatorPrefix,         dash: "Function"),
        DefKind(s: .functionMethodClass,            dash: "Method",      dp: "class func",                        tpc: .classMethod),
        DefKind(s: .varClass,                       dash: "Variable",    dp: "class var",                         tpc: .classProperty),
        DefKind(s: .class,                          dash: "Class",       dp: "class",          meta: .type,       tpc: .type),
        DefKind(s: .functionConstructor,            dash: "Constructor",                                          tpc: .initializer),
        DefKind(s: .functionDestructor,             dash: "Method",                                               tpc: .deinitializer),
        DefKind(s: .varGlobal,                      dash: "Global",      dp: "var",            meta: .variable),
        DefKind(s: .enumcase,                       dash: "Case",        dp: "case",                              tpc: .enumElement),
        DefKind(s: .enumelement,                    dash: "Case",        dp: "case",                              tpc: .enumElement),
        DefKind(s: .enum,                           dash: "enum",        dp: "enum",           meta: .type,       tpc: .type),
        DefKind(s: .extension,                      dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionClass,                 dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionEnum,                  dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionProtocol,              dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .extensionStruct,                dash: "Extension",   dp: "extension",      meta: .extension),
        DefKind(s: .functionFree,                   dash: "Global",      dp: "func",           meta: .function),
        DefKind(s: .functionMethodInstance,         dash: "Method",      dp: "func",                              tpc: .method),
        DefKind(s: .varInstance,                    dash: "Property",    dp: "var",                               tpc: .property),
        DefKind(s: .varLocal,                       dash: "Variable",    dp: "var"),
        DefKind(s: .varParameter,                   dash: "Parameter"),
        DefKind(s: .protocol,                       dash: "Protocol",    dp: "protocol",       meta: .type,       tpc: .type),
        DefKind(s: .functionMethodStatic,           dash: "Method",      dp: "static func",                       tpc: .staticMethod),
        DefKind(s: .varStatic,                      dash: "Variable",    dp: "static var",                        tpc: .staticProperty),
        DefKind(s: .struct,                         dash: "Struct",      dp: "struct",         meta: .type,       tpc: .type),
        DefKind(s: .functionSubscript,              dash: "Method",                                               tpc: .subscript),
        DefKind(s: .typealias,                      dash: "Alias",       dp: "typealias",      meta: .type,       tpc: .type),
        DefKind(s: .genericTypeParam,               dash: "Parameter"),
        DefKind(s: .associatedtype,                 dash: "Type",        dp: "associatedtype",                    tpc: .associatedType),
        DefKind(s: .opaqueType,                     dash: "Type"),
        DefKind(s: .module,                         dash: "Module"),
        DefKind(s: .precedenceGroup,                dash: "Type",        dp: "precedencegroup"),

        // not sure what to do with these yet
        DefKind(.other(key: "source.lang.swift.syntaxtype.comment.mark", isSwift: true))
    ]
}

extension DefKind: Hashable {
    public static func == (lhs: DefKind, rhs: DefKind) -> Bool {
        lhs.key == rhs.key
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

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
