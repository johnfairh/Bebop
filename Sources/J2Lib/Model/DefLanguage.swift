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
    public var otherLanguage: DefLanguage {
        switch self {
        case .swift: return .objc
        case .objc: return .swift
        }
    }

    /// Human-readable name for the language
    public var humanName: String {
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

    /// Name of language according to Prism, the code highlighter
    var prismName: String {
        switch self {
        case .swift: return "swift"
        case .objc: return "objectivec"
        }
    }

    /// Comparable
    public static func < (lhs: DefLanguage, rhs: DefLanguage) -> Bool {
        lhs.humanName < rhs.humanName
    }
}
