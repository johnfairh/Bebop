//
//  ItemKind.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Most-top level categorization of definitions
public enum ItemKind: String, CaseIterable {
    case guide
    case type
    case variable
    case function
    case `extension`
    case group
    case other

    /// The name of the kind, unambiguous and not shown in docs.
    var name: String {
        switch self {
        case .guide: return "guides"
        case .type: return "types"
        case .variable: return "variables"
        case .function: return "functions"
        case .extension: return "extensions"
        default: return "others"
        }
    }

    /// The title of the kind, shown in docs
    var title: Localized<String> {
        switch self {
        case .guide: return .localizedOutput(.guides)
        case .type: return .localizedOutput(.types)
        case .variable: return .localizedOutput(.variables)
        case .function: return .localizedOutput(.functions)
        case .extension: return .localizedOutput(.extensions)
        default: return .localizedOutput(.others)
        }
    }
}
