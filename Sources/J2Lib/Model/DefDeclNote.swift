//
//  DefDeclNote.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// A note about a declaration
public enum DeclNote: Hashable {
    /// A non-customization point in a protocol
    case protocolExtensionMember
    /// A protocol method with a default implementation
    case defaultImplementation
    /// A protocol method with default implementations provided by conditional extensions
    case conditionalDefaultImplementationExists
    /// A default implementation of a protocl method in a conditional extension
    case conditionalDefaultImplementation
    /// An extension member imported from a different module to the type
    case imported(String)
    /// A default implementation of a protocol from an imported extension
    case importedDefaultImplementation(String)

    /// Get the message for the note
    public var localized: Localized<String> {
        switch self {
        case .protocolExtensionMember:
            return .localizedOutput(.protocolExtn)
        case .defaultImplementation:
            return .localizedOutput(.protocolDefault)
        case .conditionalDefaultImplementationExists:
            return .localizedOutput(.protocolDefaultConditionalExists)
        case .conditionalDefaultImplementation:
            return .localizedOutput(.protocolDefaultConditional)
        case .imported(let module):
            return .localizedOutput(.imported, module)
        case .importedDefaultImplementation(let module):
            return .localizedOutput(.protocolDefaultImported, module)
        }
    }
}

extension DeclNote: Encodable {
    private enum CodingKeys: String, CodingKey {
        case protocolExtensionMember
        case defaultImplementation
        case conditionalDefaultImplementationExists
        case conditionalDefaultImplementation
        case imported
        case importedDefaultImplementation
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .protocolExtensionMember:
            try container.encode(true, forKey: .protocolExtensionMember)
        case .defaultImplementation:
            try container.encode(true, forKey: .defaultImplementation)
        case .conditionalDefaultImplementation:
            try container.encode(true, forKey: .conditionalDefaultImplementation)
        case .conditionalDefaultImplementationExists:
            try container.encode(true, forKey: .conditionalDefaultImplementationExists)
        case .imported(let module):
            try container.encode(module, forKey: .imported)
        case .importedDefaultImplementation(let module):
            try container.encode(module, forKey: .importedDefaultImplementation)
        }
    }
}

/// Define a order for multiple decl notes, lots are exclusive in practice.
extension DeclNote: Comparable {
    public static func < (lhs: DeclNote, rhs: DeclNote) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    var sortOrder: Int {
        switch self {
        case .imported(_): return 0
        case .protocolExtensionMember: return 1
        case .defaultImplementation: return 2
        case .conditionalDefaultImplementationExists: return 3
        case .conditionalDefaultImplementation: return 4
        case .importedDefaultImplementation(_): return 5
        }
    }
}
