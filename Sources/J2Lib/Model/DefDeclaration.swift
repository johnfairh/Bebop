//
//  DefDeclaration.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// MARK: Common Types

/// A piece of a declaration along with its style metadata
public enum DeclarationPiece: Equatable {
    case name(String)
    case other(String)

    // Fallback for when the declaration can't be destructured
    init(_ flat: String) {
        self = .other(flat.re_sub("\\s+", with: " "))
    }

    public var isName: Bool {
        switch self {
        case .name(_): return true
        case .other(_): return false
        }
    }

    public var text: String {
        switch self {
        case .name(let text): return text
        case .other(let text): return text
        }
    }

    public var nameText: String? {
        switch self {
        case .name(let text): return text
        case .other(_): return nil
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
    public var flattened: String {
        map { $0.text }.joined()
    }

    public var flattenedName: String {
        compactMap { $0.nameText }.joined()
    }

    public func wrappingOther(before: String, after: String) -> String {
        map {
            switch $0 {
            case .name(let str): return str
            case .other(let str): return before + str + after
            }
        }.joined()
    }
}

/// A USR.
///
/// Understanding the structure of this is a fallback when we don't have properly spelt-out data
/// through a formal interface.
public struct USR: Encodable, CustomStringConvertible, Hashable {
    public let value: String
    public var description: String { value }
    init(_ value: String) { self.value = value }

    /// Given the USR of an ObjC category, make the USR for the class
    init?(classFromCategoryUSR usr: USR) {
        // c:objc(cy)Type@Cat -> c:objc(cs)Type
        guard let match = usr.value.re_match(#"(?<=\(cy\)).*(?=@)"#) else {
            return nil
        }
        value = "c:objc(cs)" + match[0]
    }
}

// MARK: Swift Specific

/// A Swift language declaration split into its various parts
public final class SwiftDeclaration: Encodable {
    /// Possibly multi-line declaration, for verbatim display
    public internal(set) var declaration: RichDeclaration
    /// Deprecation messages, or `nil` if not deprecated (XXX Markdown?)
    public let deprecation: Localized<String>?
    /// List of availability conditions
    public internal(set) var availability: [String]
    /// Declaration split into name and non-name pieces, for making an item title
    public let namePieces: [DeclarationPiece]
    /// For extensions, the module name of the type
    public let typeModuleName: String?
    /// Names of inherited types
    public internal(set) var inheritedTypes: [String]
    /// Is this declaration overriding one from a supertype or protocol?
    public let isOverride: Bool

    init(declaration: String = "",
         deprecation: Localized<String>? = nil,
         availability: [String] = [],
         namePieces: [DeclarationPiece] = [],
         typeModuleName: String? = nil,
         inheritedTypes: [String] = [],
         isOverride: Bool = false) {
        self.declaration = RichDeclaration(declaration)
        self.deprecation = deprecation
        self.availability = availability
        self.namePieces = namePieces
        self.typeModuleName = typeModuleName
        self.inheritedTypes = inheritedTypes
        self.isOverride = isOverride
    }
}

/// Swift generic requirements helpers - constrained extensions and the incredible
/// complications that ensue mean we have to shovel these around in unexpected ways.
public struct SwiftGenericReqs: Encodable {
    /// The requirements without the leading 'where'
    private let reqs: String

    init?(declaration: String) {
        // this is a pretty dodgy, could use SwiftSyntax to get it...
        guard let match = declaration.re_match(#"\bwhere\s+(.*)$"#, options: .s) else {
            return nil
        }
        reqs = match[1].re_sub(#"\s+"#, with: " ")
    }

    /// Requirements in plain text with a leading 'where'
    public var text: String {
        "where " + reqs
    }

    /// Requirements in markdown, type names code-d
    public var markdown: Markdown {
        Markdown("where " + reqs.re_sub(#"[\w\.]+"#, with: #"`$0`"#))
    }

    /// Rich text version of constrained, 'Available where ....'
    public var richLong: RichText {
        RichText(.localizedOutput(.availableWhere, markdown.md))
    }

    /// Truncated rich text version of constraint, '&ldots;where ...'
    public var richShort: RichText {
        RichText(.localizedOutput(.availableWhereShort, markdown.md))
    }
}

// MARK: Objective-C Specific

/// An Objective-C declaration split into its various parts
public final class ObjCDeclaration: Encodable {
    /// Possibly multi-line declaration, for verbatim display
    public internal(set) var declaration: RichDeclaration
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
        self.declaration = RichDeclaration(declaration)
        self.deprecation = deprecation
        self.unavailability = unavailability
        self.namePieces = namePieces
    }
}

/// A wrapper to unpack "Foo(bar)" category names
public struct ObjCCategoryName {
    /// The name of the type being extended
    public let className: String
    /// The name of the category (does this have any semantic value?)
    public let categoryName: String
    /// Try to break down a compound category name
    init?(_ compound: String) {
        guard let matches = compound.re_match(#"(\w*)\((\w*)\)"#) else {
            return nil
        }
        self.className = matches[1]
        self.categoryName = matches[2]
    }
}
