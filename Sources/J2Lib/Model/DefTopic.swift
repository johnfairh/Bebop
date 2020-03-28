//
//  DefTopic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The topics that definitions are automatically split into within a type.
/// The order of the enum matches the order on the page.
public enum DefTopic: Int, CaseIterable, Comparable {
    case associatedType
    case type
    case initializer
    case deinitializer
    case enumElement
    case method
    case property
    case field
    case `subscript`
    case staticMethod
    case staticProperty
    case staticSubscript
    case classMethod
    case classProperty
    case classSubscript
    case other

    private var nameKey: L10n.Output {
        switch self {
        case .associatedType: return .tpcAssociatedTypes
        case .type: return .tpcTypes
        case .initializer: return .tpcInitializers
        case .deinitializer: return .tpcDeinitializer
        case .enumElement: return .tpcEnumElements
        case .method: return .tpcMethods
        case .property: return .tpcProperties
        case .field: return .tpcFields
        case .subscript: return .tpcSubscripts
        case .staticMethod: return .tpcStaticMethods
        case .staticProperty: return .tpcStaticProperties
        case .staticSubscript: return .tpcStaticSubscripts
        case .classMethod: return .tpcClassMethods
        case .classProperty: return .tpcClassProperties
        case .classSubscript: return .tpcClassSubscripts
        case .other: return .tpcOthers
        }
    }

    public var name: Localized<String> {
        .localizedOutput(nameKey)
    }

    public static func < (lhs: DefTopic, rhs: DefTopic) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
