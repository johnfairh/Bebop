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

/// The programming language, Swift or Objective-C.
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

    /// Human-readable name for the language
    var humanName: String {
        switch self {
        case .swift: return "Swift"
        case .objc: return "Objective C"
        }
    }
}

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
    public let inheritedTypes: [String]

    init(declaration: String = "",
         deprecation: Localized<String>? = nil,
         availability: [String] = [],
         namePieces: [DeclarationPiece] = [],
         typeModuleName: String? = nil,
         inheritedTypes: [String] = []) {
        self.declaration = RichDeclaration(declaration)
        self.deprecation = deprecation
        self.availability = availability
        self.namePieces = namePieces
        self.typeModuleName = typeModuleName
        self.inheritedTypes = inheritedTypes
    }
}

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
    public init?(_ compound: String) {
        guard let matches = compound.re_match(#"(\w*)\((\w*)\)"#) else {
            return nil
        }
        self.className = matches[1]
        self.categoryName = matches[2]
    }
}

/// Where a definition was written
public struct DefLocation: Encodable, CustomStringConvertible {
    /// Name of the module the definition belongs to.  If the definition is an extension of
    /// a type from a different module then this is the extension's module not the type's.
    public let moduleName: String
    /// Gather pass through the module
    public let passIndex: Int
    /// Full pathname of the definition's source file.  Nil only after some kind of binary gather.
    public let filePathname: String?
    /// First line in the file.  Nil if we don't know it.  Line numbers start at 1.
    public let firstLine: Int?
    /// Last line in the file of the definition.  Can be same as `firstLine`.
    public let lastLine: Int?

    public var description: String {
        let file = filePathname ?? "(??)"
        let from = firstLine ?? 0
        let to = lastLine ?? 0
        return "[\(moduleName):\(passIndex) \(file) ll\(from)-\(to)]"
    }
}

/// A USR.
///
/// Understanding the structure of this is a fallback when we don't have properly spelt-out data
/// through a formal interface.
public struct USR: Encodable, CustomStringConvertible, Hashable {
    public let value: String
    public var description: String { value }
    public init(_ value: String) { self.value = value }

    /// Given the USR of an ObjC category, make the USR for the class
    public init?(classFromCategoryUSR usr: USR) {
        // c:objc(cy)Type@Cat -> c:objc(cs)Type
        guard let match = usr.value.re_match(#"(?<=\(cy\)).*(?=@)"#) else {
            return nil
        }
        value = "c:objc(cs)" + match[0]
    }
}
