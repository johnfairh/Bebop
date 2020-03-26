//
//  DefLanguage.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The programming language, Swift or Objective-C.
public enum DefLanguage: String, Encodable, CaseIterable, Comparable {
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

    /// CSS-name for the language
    public var cssName: String {
        switch self {
        case .swift: return "j2-swift"
        case .objc: return "j2-objc"
        }
    }

    /// Comparable
    public static func < (lhs: DefLanguage, rhs: DefLanguage) -> Bool {
        lhs.humanName < rhs.humanName
    }
}
