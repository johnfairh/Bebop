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
public final class DefKind {
    /// The underlying key
    private let kindKey: Key
    /// The sourcekit[ten] key for the definition type
    public var key: String { kindKey.key }
    /// Is this a Swift definition kind?
    public var isSwift: Bool { kindKey.isSwift }
    /// The name of the declaration type in the generated docs [translate??]
    public let uiName: String
    /// The metakind for the definition type
    public let metaKind: ItemKind
    /// The name of the declaration type per Dash rules, revised Jan 2020
    /// (https://kapeli.com/docsets#supportedentrytypes))
    public var dashName: String { _dashName ?? uiName }
    public let _dashName: String?
    /// The Swift keywords that should precede the declaration name
    public let declPrefix: String?

    /// The underlying sourcekitten key - keep hold of the enum to avoid string comparisons (right?)
    private enum Key {
        case swift(SwiftDeclarationKind)
        #if os(macOS)
        case objC(ObjCDeclarationKind, SwiftDeclarationKind?)
        #else
        // sourcekitten doesn't have objc on linux, this gives things the right shape.
        case objC(SwiftDeclarationKind, SwiftDeclarationKind?)
        #endif
        // Only for swift 'MARK' comments rn...
        case other(key: String, isSwift: Bool)

        var isSwift: Bool {
            switch self {
            case .swift(_): return true;
            case .objC(_, _): return false;
            case .other(_, let isSwift): return isSwift;
            }
        }

        var key: String {
            switch self {
            case .swift(let kind): return kind.rawValue
            case .objC(let kind, _): return kind.rawValue
            case .other(let key, _): return key
            }
        }
    }

    private init(_ kindKey: Key,
                 _ uiName: String,
                 dashName: String? = nil,
                 declPrefix: String? = nil,
                 metaKind: ItemKind = .other) {
        self.kindKey = kindKey
        self.uiName = uiName
        self._dashName = dashName
        self.declPrefix = declPrefix
        self.metaKind = metaKind
    }

    #if os(macOS)
    private convenience init(o key: ObjCDeclarationKind,
                             _ uiName: String,
                             s swiftKey: SwiftDeclarationKind? = nil,
                             dash: String? = nil,
                             meta metaKind: ItemKind = .other) {
        self.init(.objC(key, swiftKey),
                  uiName,
                  dashName: dash,
                  declPrefix: nil,
                  metaKind: metaKind)
    }
    #endif

    private convenience init(s key: SwiftDeclarationKind,
                             _ uiName: String,
                             dash: String? = nil,
                             dp: String? = nil,
                             meta metaKind: ItemKind = .other) {
        self.init(.swift(key),
                  uiName,
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind)
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

    /// EnumCase is the useless wrapper, we want the enumelement within
    var isSwiftEnumCase: Bool {
        testSwiftKey(keys: [.enumcase])
    }

    var isSwiftEnum: Bool {
        testSwiftKey(keys: [.enum])
    }

    /// Is this a mark -- an objC `#pragma mark` or a Swift // MARK: - like comment
    var isMark: Bool {
        if case .other(_) = kindKey {
            return true
        }
        #if os(macOS)
        if case let .objC(k, _) = kindKey {
            return k == .mark
        }
        #endif
        return false
    }

    // MARK: Factory

    /// Find the `Kind` object from a sourcekitten dictionary key, or `nil` if it's not supported
    public static func from(key: String) -> DefKind? {
        return kindMap[key]
    }

    /// Cache string -> Kind
    private static let kindMap: [String : DefKind] = {
        var map: [String: DefKind] = [:]
        allSwiftKinds.forEach { map[$0.key] = $0 }
        #if os(macOS)
        allObjCKinds.forEach { map[$0.key] = $0 }
        #endif
        return map
    }()

    /// Sequence access to kinds list
    public static var all: [DefKind] { // should be `some Sequence` !
        #if os(macOS)
        return allObjCKinds + allSwiftKinds
        #else
        return allSwiftKinds
        #endif
    }

    /// Master list of kinds.  I've superstitiously kept the jazzy ordering, which might affect the default
    /// ordering somewhere - tbd.

    #if os(macOS)
    private static let allObjCKinds: [DefKind] = [
        // Objective-C
        DefKind(o: .unexposedDecl,  "Unexposed"),
        DefKind(o: .category,       "Category",         s: .extension,              dash: "Extension", meta: .extension),
        DefKind(o: .class,          "Class",            s: .class,                                     meta: .type),
        DefKind(o: .constant,       "Constant",         s: .varGlobal,                                 meta: .variable),
        DefKind(o: .enum,           "Enumeration",      s: .enum,                   dash: "Enum",      meta: .type),
        DefKind(o: .enumcase,       "Enumeration Case", s: .enumelement,            dash: "Case"),
        DefKind(o: .initializer,    "Initializer",      s: .functionConstructor),
        DefKind(o: .methodClass,    "Class Method",     s: .functionMethodClass,    dash: "Method"),
        DefKind(o: .methodInstance, "Instance Method",  s: .functionMethodInstance, dash: "Method"),
        DefKind(o: .property,       "Property",         s: .varInstance),
        DefKind(o: .protocol,       "Protocol",         s: .protocol,                                  meta: .type),
        DefKind(o: .typedef,        "Type Definition",  s: .typealias,              dash: "Type",      meta: .type),
        DefKind(o: .mark,           "Mark"),
        DefKind(o: .function,       "Function",         s: .functionFree,                              meta: .function),
        DefKind(o: .struct,         "Structure",        s: .struct,                 dash: "Struct",    meta: .type),
        DefKind(o: .field,          "Field",            s: .varInstance),
        DefKind(o: .ivar,           "Instance Variable",                            dash: "Variable"),
        DefKind(o: .moduleImport,   "Module"),
    ]
    #endif

    private static let allSwiftKinds: [DefKind] = [
        // Swift
        // Most of these are inaccessible - generated by other parts of SourceKit (or not
        // at all) or filtered out before we think about documenting them, but it's easier
        // to just list them all.
        DefKind(s: .functionAccessorAddress,        "Addressor",              dash: "Function"),
        DefKind(s: .functionAccessorDidset,         "didSet Observer",        dash: "Function"),
        DefKind(s: .functionAccessorGetter,         "Getter",                 dash: "Function"),
        DefKind(s: .functionAccessorMutableaddress, "Mutable Addressor",      dash: "Function"),
        DefKind(s: .functionAccessorSetter,         "Setter",                 dash: "Function"),
        DefKind(s: .functionAccessorWillset,        "willSet Observer",       dash: "Function"),
        DefKind(s: .functionAccessorRead,           "Read Accessor",          dash: "Function"),
        DefKind(s: .functionAccessorModify,         "Modify Accessor",        dash: "Function"),
        DefKind(s: .functionOperatorInfix,          "Infix Operator",         dash: "Function"),
        DefKind(s: .functionOperatorPostfix,        "Postfix Operator",       dash: "Function"),
        DefKind(s: .functionOperatorPrefix,         "Prefix Operator",        dash: "Function"),
        DefKind(s: .functionMethodClass,            "Class Method",           dash: "Method",      dp: "class func"),
        DefKind(s: .varClass,                       "Class Variable",         dash: "Variable",    dp: "class var"),
        DefKind(s: .class,                          "Class",                                       dp: "class",            meta: .type),
        DefKind(s: .functionConstructor,            "Initializer",            dash: "Constructor"),
        DefKind(s: .functionDestructor,             "Deinitializer",          dash: "Method"),
        DefKind(s: .varGlobal,                      "Global Variable",        dash: "Global",      dp: "var",              meta: .variable),
        DefKind(s: .enumcase,                       "Enumeration Case",       dash: "Case",        dp: "case"),
        DefKind(s: .enumelement,                    "Enumeration Element",    dash: "Case",        dp: "case"),
        DefKind(s: .enum,                           "Enumeration",            dash: "enum",        dp: "enum",             meta: .type),
        DefKind(s: .extension,                      "Extension",                                   dp: "extension",        meta: .extension),
        DefKind(s: .extensionClass,                 "Extension",                                   dp: "extension",        meta: .extension),
        DefKind(s: .extensionEnum,                  "Extension",                                   dp: "extension",        meta: .extension),
        DefKind(s: .extensionProtocol,              "Extension",                                   dp: "extension",        meta: .extension),
        DefKind(s: .extensionStruct,                "Extension",                                   dp: "extension",        meta: .extension),
        DefKind(s: .functionFree,                   "Global Function",        dash: "Global",      dp: "func",             meta: .function),
        DefKind(s: .functionMethodInstance,         "Instance Method",        dash: "Method",      dp: "func"),
        DefKind(s: .varInstance,                    "Instance Variable",      dash: "Property",    dp: "var"),
        DefKind(s: .varLocal,                       "Local Variable",         dash: "Variable",    dp: "var"),
        DefKind(s: .varParameter,                   "Parameter",              dash: "Parameter"),
        DefKind(s: .protocol,                       "Protocol",                                    dp: "protocol",         meta: .type),
        DefKind(s: .functionMethodStatic,           "Static Method",          dash: "Method",      dp: "static func"),
        DefKind(s: .varStatic,                      "Static Variable",        dash: "Variable",    dp: "static var"),
        DefKind(s: .struct,                         "Structure",              dash: "Struct",      dp: "struct",           meta: .type),
        DefKind(s: .functionSubscript,              "Subscript",              dash: "Method"),
        // XXX should we work around the static subscript cockup?
        DefKind(s: .typealias,                      "Type Alias",             dash: "Alias",       dp: "typealias",        meta: .type),
        DefKind(s: .genericTypeParam,               "Generic Type Parameter", dash: "Parameter"),
        DefKind(s: .associatedtype,                 "Associated Type",        dash: "Type",        dp: "associatedtype"),
        DefKind(s: .opaqueType,                     "Opaque Type",            dash: "Type"),
        DefKind(s: .module,                         "Module"),
        DefKind(s: .precedenceGroup,                "Precedence Group",       dash: "Type",        dp: "precedencegroup"),

        // not sure what to do with these yet
        DefKind(.other(key: "source.lang.swift.syntaxtype.comment.mark", isSwift: true), "Mark")
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
