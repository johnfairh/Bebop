//
//  DefDeclaration.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// A piece of a declaration along with its style metadata
public enum DeclarationPiece {
    case name(String)
    case other(String)

    // Fallback for when the declaration can't be destructured
    init(_ flat: String) {
        self = .other(flat.re_sub("\\s+", with: " "))
    }

    var isName: Bool {
        switch self {
        case .name(_): return true
        case .other(_): return false
        }
    }

    var text: String {
        switch self {
        case .name(let text): return text
        case .other(let text): return text
        }
    }
}

extension DeclarationPiece: Encodable {
    enum CodingKeys: String, CodingKey {
        case name
        case other
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .name(let str): try container.encode(str, forKey: .name)
        case .other(let str): try container.encode(str, forKey: .other)
        }
    }
}

extension Array where Element == DeclarationPiece {
    var flattened: String {
        map { $0.text }.joined()
    }

    func wrappingOther(before: String, after: String) -> String {
        map {
            switch $0 {
            case .name(let str): return str
            case .other(let str): return before + str + after
            }
        }.joined()
    }
}

public enum DefLanguage: String, Encodable, CaseIterable {
    case swift
    case objc

    /// The other language
    var otherLanguage: DefLanguage {
        switch self {
        case .swift: return .objc
        case .objc: return .swift
        }
    }

    /// Name of language according to Prism, the code highlighter
    var prismLanguage: String {
        switch self {
        case .swift: return "swift"
        case .objc: return "objectivec"
        }
    }

    /// Thing to include in a URL to force this language
    var urlQuery: String {
        switch self {
        case .swift: return "?swift"
        case .objc: return "?objc"
        }
    }

    /// CSS-name for the language
    var cssName: String {
        switch self {
        case .swift: return "j2-swift"
        case .objc: return "j2-objc"
        }
    }

    /// Screen-reader name for the language
    var screenReaderName: String {
        switch self {
        case .swift: return "Swift"
        case .objc: return "Objective C"
        }
    }
}

/// A Swift language declaration split into its various parts
public struct SwiftDeclaration: Encodable {
    /// Possibly multi-line declaration, for verbatim display
    public let declaration: String
    /// Deprecation messages, or `nil` if not deprecated (XXX Markdown?)
    public let deprecation: Localized<String>?
    /// List of availability conditions
    public let availability: [String]
    /// Declaration split into name and non-name pieces, for making an item title
    public let namePieces: [DeclarationPiece]

    init(declaration: String = "",
         deprecation: Localized<String>? = nil,
         availability: [String] = [],
         namePieces: [DeclarationPiece] = []) {
        self.declaration = declaration
        self.deprecation = deprecation
        self.availability = availability
        self.namePieces = namePieces
    }
}

/// An Objective-C declaration split into its various parts
public struct ObjCDeclaration: Encodable {
    /// Possibly multi-line declaration, for verbatim display
    public let declaration: String
    /// Deprecation messages, or `nil` if not deprecated (XXX Markdown?)
    public let deprecation: Localized<String>?
    /// Unavailability messages, or `nil` if not unavailable (XXX Markdown?)
    public let unavailability: Localized<String>?
    /// Declaration split into name and non-name pieces, for making an item title
    public let namePieces: [DeclarationPiece]

    init(declaration: String = "",
         deprecation: Localized<String>? = nil,
         unavailability: Localized<String>? = nil,
         namePieces: [DeclarationPiece] = []) {
        self.declaration = declaration
        self.deprecation = deprecation
        self.unavailability = unavailability
        self.namePieces = namePieces
    }
}
