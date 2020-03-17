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
        case .guide: return "Guides"
        case .type: return "Types"
        case .variable: return "Variables"
        case .function: return "Functions"
        case .extension: return "Extensions"
        default: return "Others"
        }
    }

    /// The title of the kind, shown in docs, for Swift/ObjC
    func title(in language: DefLanguage, affix: Localized<String>? = nil) -> Localized<String> {
        switch self {
        case .guide: return .localizedOutput(.guides)
        case .type: return .localizedOutput(.types)
        case .variable: return .localizedOutput(.variables)
        case .function: return .localizedOutput(.functions)
        case .extension:
            switch language {
            case .swift: return .localizedOutput(.extensions)
            case .objc: return .localizedOutput(.categories)
            }
        default: return .localizedOutput(.others)
        }
    }

    /// Is this kind to do with code (matches/will match/did match a DefItem)
    var isCode: Bool {
        switch self {
        case .guide, .group: return false
        case .type, .variable, .function, .extension, .other: return true
        }
    }
}
