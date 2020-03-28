//
//  Localization.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

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
    init(descriptor: String) {
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

    /// Lookup from tag, or main if no match
    public func localization(languageTag: String) -> Localization {
        for loc in all {
            if loc.tag == languageTag {
                return loc
            }
        }
        return main
    }

    /// Initialize a new set of localizations
    init(main: Localization = .default, others: [Localization] = []) {
        self.main = main
        self.others = others
    }

    /// Initialize a new set of localizations from descriptors
    init(mainDescriptor: String?, otherDescriptors: [String]) {
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
    public internal(set) static var shared = Localizations()
}
