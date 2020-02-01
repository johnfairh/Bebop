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
// This `Kind` type only needs to cover definitions, the plan goes, because Guides
// and Groups will have some separate type-info to differentiate them.  We'll see.
//

/// The underlying sourcekitten key - keep hold of the enum to avoid string comparisons (right?)
private enum DefKindKey {
    case swift(SwiftDeclarationKind)
    #if os(Linux)
    // sourcekitten doesn't have OCDK on linux, this gives things the right shape.
    case objC(SwiftDeclarationKind)
    #else
    case objC(ObjCDeclarationKind)
    #endif
    // Only for swift 'MARK' comments rn...
    case other(key: String, isSwift: Bool)

    var isSwift: Bool {
        switch self {
        case .swift(_): return true;
        case .objC(_): return false;
        case .other(_, let isSwift): return isSwift;
        }
    }

    var key: String {
        switch self {
        case .swift(let kind): return kind.rawValue
        case .objC(let kind): return kind.rawValue
        case .other(let key, _): return key
        }
    }
}

/// The type of a definition 
public final class DefKind {
    /// The underlying key
    private let kindKey: DefKindKey
    /// The sourcekit[ten] key for the definition type
    public var key: String { kindKey.key }
    /// Is this a Swift definition kind?
    public var isSwift: Bool { kindKey.isSwift }
    /// The name of the declaration type in the generated docs [translate??]
    public let uiName: String
    /// The metakind for the definition type
    public let metaKind: MetaKind
    /// The name of the declaration type per Dash rules, revised Jan 2020
    /// (https://kapeli.com/docsets#supportedentrytypes))
    public var dashName: String { _dashName ?? uiName }
    public let _dashName: String?
    /// The Swift keywords that should precede the declaration name
    public let declPrefix: String?

    private init(_ kindKey: DefKindKey,
                 _ uiName: String,
                 dashName: String? = nil,
                 declPrefix: String? = nil,
                 metaKind: MetaKind = .other) {
        self.kindKey = kindKey
        self.uiName = uiName
        self._dashName = dashName
        self.declPrefix = declPrefix
        self.metaKind = metaKind
    }

    #if !os(Linux)
    private convenience init(o key: ObjCDeclarationKind,
                             _ uiName: String,
                             dash: String? = nil,
                             meta metaKind: MetaKind = .other) {
        self.init(.objC(key),
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
                             meta metaKind: MetaKind = .other) {
        self.init(.swift(key),
                  uiName,
                  dashName: dash,
                  declPrefix: dp,
                  metaKind: metaKind)
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

    // MARK: Factory

    /// Find the `Kind` object from a sourcekitten dictionary key, or `nil` if it's not supported
    public static func from(key: String) -> DefKind? {
        if kindMap.isEmpty {
            allSwiftKinds.forEach {
                kindMap[$0.key] = $0
            }
            #if !os(Linux)
            allObjCKinds.forEach {
                kindMap[$0.key] = $0
            }
            #endif
        }
        return kindMap[key]
    }

    /// Cache string -> Kind
    private static var kindMap: [String : DefKind] = [:]

    /// Master list of kinds.  I've superstitiously kept the jazzy ordering, which might affect the default
    /// ordering somewhere - tbd.

    #if !os(Linux)
    private static let allObjCKinds: [DefKind] = [
        // Objective-C
        DefKind(o: .unexposedDecl,  "Unexposed"),
        DefKind(o: .category,       "Category",          dash: "Extension", meta: .category),
        DefKind(o: .class,          "Class",                                meta: .type),
        DefKind(o: .constant,       "Constant",                             meta: .variable),
        DefKind(o: .enum,           "Enumeration",       dash: "Enum",      meta: .type),
        DefKind(o: .enumcase,       "Enumeration Case",  dash: "Case"),
        DefKind(o: .initializer,    "Initializer"),
        DefKind(o: .methodClass,    "Class Method",      dash: "Method"),
        DefKind(o: .methodInstance, "Instance Method",   dash: "Method"),
        DefKind(o: .property,       "Property"),
        DefKind(o: .protocol,       "Protocol",                             meta: .type),
        DefKind(o: .typedef,        "Type Definition",   dash: "Type",      meta: .type),
        DefKind(o: .mark,           "Mark"),
        DefKind(o: .function,       "Function",                             meta: .function),
        DefKind(o: .struct,         "Structure",         dash: "Struct",    meta: .type),
        DefKind(o: .field,          "Field"),
        DefKind(o: .ivar,           "Instance Variable", dash: "Variable"),
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
