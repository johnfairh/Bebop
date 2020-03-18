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
        func l(_ regular: L10n.Output, _ custom: L10n.Output) -> Localized<String> {
            if let affix = affix {
                return .localizedOutput(custom, affix)
            }
            return .localizedOutput(regular)
        }

        switch self {
        case .guide: return l(.guides, .guides)
        case .type: return l(.types, .typesCustom)
        case .variable: return l(.variables, .variablesCustom)
        case .function: return l(.functions, .functionsCustom)
        case .extension:
            switch language {
            case .swift: return l(.extensions, .extensionsCustom)
            case .objc: return l(.categories, .categoriesCustom)
            }
        default: return l(.others, .othersCustom)
        }
    }
}
