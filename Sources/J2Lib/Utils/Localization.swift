//
//  Localization.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Describe a localization of the eventual docs being generated.
public struct Localization: CustomStringConvertible, Hashable, Encodable, Comparable {
    /// The language tag.  Used to identify localized doc comment strings files and templates,
    /// contribute to the URL in the generated site.
    public var tag: String
    /// A flag or similarly-sized thing to appear in the UI
    public var flag: String
    /// The name of the localization to appear in a menu in the UI
    public var label: String

    public var description: String {
        "\(tag):\(flag):\(label)"
    }

    public static func < (lhs: Localization, rhs: Localization) -> Bool {
        lhs.description < rhs.description
    }

    /// Initialize a new `Localization`.  The descriptor contains the tag, flag, and label,
    /// separated by colons.
    public init(descriptor: String) {
        let pieces = descriptor.split(separator: ":", maxSplits: 2)
        tag = String(pieces[0])
        if pieces.count > 1 {
            flag = String(pieces[1])
        } else {
            flag = "🇺🇳"
        }
        if pieces.count > 2 {
            label = String(pieces[2])
        } else {
            label = tag
        }
    }

    /// The default default localization descriptor
    public static let defaultDescriptor = "en:🇺🇸:English"
    public static let `default` = Localization(descriptor: defaultDescriptor)
}

/// A working set of localizations
public struct Localizations {
    /// The main localization -- in practice, what do site URLs default to
    public let main: Localization
    /// The seconary localizations -- in practice, live in subdirectories.
    public let others: [Localization]

    /// All localizations
    public var all: [Localization] {
        [main] + others
    }

    /// All tags
    public var allTags: [String] {
        all.map { $0.tag }
    }

    /// Initialize a new set of localizations
    public init(main: Localization = .default, others: [Localization] = []) {
        self.main = main
        self.others = others
    }

    /// Initialize a new set of localizations from descriptors
    public init(mainDescriptor: String?, otherDescriptors: [String]) {
        main = Localization(descriptor: mainDescriptor ?? Localization.defaultDescriptor)

        // remove dups from the other-list
        var otherLocalizations = Set<Localization>(
            otherDescriptors.map(Localization.init)
        )
        // ...and don't dup the main to the others
        otherLocalizations.remove(main)
        others = Array(otherLocalizations).sorted()
    }

    /// The current active localization settings.  This is needed in all kinds of leaf places and passing it around
    /// and through often as so much tramp data is really ugly.
    public static var shared = Localizations()
}

// MARK: Multistrings

/// Keyed by language tag
public typealias Localized<T> = [String : T]

extension Dictionary where Key == String {
    /// Create a 'localized' version a value, showing that value for every language tag
    public init(unLocalized: Value) {
        self.init()
        Localizations.shared.allTags.forEach {
            self[$0] = unLocalized
        }
    }

    /// Ensure there is a value for every language tag.
    /// Defaults to the main localization if set, otherwise arbitrary.
    /// Shouldn't really be here if empty, does nothing.
    /// - returns: the list of tags that were invented
    @discardableResult
    public mutating func expandLanguages() -> [String] {
        guard let anyValue = self.first?.value else {
            return Localizations.shared.allTags
        }
        let defaultValue = self[Localizations.shared.main.tag]
        var missingTags = [String]()
        Localizations.shared.allTags.forEach { tag in
            if self[tag] == nil {
                self[tag] = defaultValue ?? anyValue
                missingTags.append(tag)
            }
        }
        return missingTags
    }
}

extension Dictionary where Key == String, Value == String {
    /// Helper to grab a piece of localized output text and do substitutions %1 .... %n
    static func localizedOutput(_ key: L10n.Output, _ subs: Any...) -> Localized<String> {
        Resources.shared.localizedOutput(key: key.rawValue, subs: subs)
    }

    init(_ key: L10n.Output, _ subs: Any...) {
        self = Resources.shared.localizedOutput(key: key.rawValue, subs: subs)
    }

    public func append(_ str: Localized<String>) -> Self {
        var out = Localized<String>()
        forEach { key, val in
            out[key] = val + str.get(key)
        }
        return out
    }

    public func append(_ str: String) -> Self {
        mapValues { $0 + str }
    }

    /// Get the value for the language or an empty string if none
    func get(_ languageTag: String) -> String {
        self[languageTag] ?? ""
    }
}

extension Array where Element == Localized<String> {
    public func joined(by: String) -> Element {
        var output = Element()
        forEach { str in
            str.forEach { k, value in
                if let current = output[k] {
                    output[k] = current + by + value
                } else {
                    output[k] = value
                }
            }
        }
        return output
    }
}
