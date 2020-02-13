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

/// A Swift language declaration split into its various parts
public struct SwiftDeclaration: Encodable {
    public let declaration: String
    public let deprecation: Localized<String>
    public let availability: [String]
    public let namePieces: [DeclarationPiece]

    init(declaration: String = "",
         deprecation: Localized<String> = [:],
         availability: [String] = [],
         namePieces: [DeclarationPiece] = []) {
        self.declaration = declaration
        self.deprecation = deprecation
        self.availability = availability
        self.namePieces = namePieces
    }
}
