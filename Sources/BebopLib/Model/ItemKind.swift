//
//  ItemKind.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// Most-top level categorization of definitions
public enum ItemKind: String, CaseIterable, Sendable {
    case guide
    case type
    case variable
    case function
    case `operator`
    case `extension`
    case group
    case other

    /// The name of the kind, unambiguous and not shown in docs.
    public var name: String {
        switch self {
        case .guide: return "Guides"
        case .type: return "Types"
        case .variable: return "Variables"
        case .function: return "Functions"
        case .operator: return "Operators"
        case .extension: return "Extensions"
        case .group, .other: return "Others"
        }
    }

    /// The title of the kind, shown in docs, for Swift/ObjC
    public func title(in language: DefLanguage, affix: Localized<String>? = nil) -> Localized<String> {
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
        case .operator: return l(.operators, .operatorsCustom)
        case .extension:
            switch language {
            case .swift: return l(.extensions, .extensionsCustom)
            case .objc: return l(.categories, .categoriesCustom)
            }
        case .group, .other: return l(.others, .othersCustom)
        }
    }
}
