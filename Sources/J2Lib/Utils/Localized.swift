//
//  Localized.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// Set of helpers for working with things that are localized where we need all
// of some set of localizations at the same time -- because we are generating
// a multi-localization documentation bundle.
//

// MARK: Type

/// Keyed by language tag
public typealias Localized<T> = [String : T]

// MARK: Localized construction

extension Dictionary where Key == String {
    /// Create a 'localized' version a value, showing that value for every language tag
    init(unlocalized: Value) {
        self.init()
        Localizations.shared.allTags.forEach {
            self[$0] = unlocalized
        }
    }

    /// Ensure there is a value for every language tag.
    /// Defaults to the main localization if set, otherwise arbitrary.
    /// Shouldn't really be here if empty, does nothing.
    /// - returns: the list of tags that were invented
    @discardableResult
    mutating func expandLanguages() -> [String] {
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

// MARK: Localized strings

public protocol NulInitializable {
    init()
}

public protocol Appendable {
    static func +(lhs: Self, rhs: Self) -> Self
    static func +(lhs: Self, rhs: String) -> Self
}

extension String : NulInitializable, Appendable {}
extension BoxedString: NulInitializable, Appendable { public init() { self.init("") } }
extension Array: NulInitializable {}
extension Dictionary: NulInitializable {}

extension Dictionary where Key == String, Value == String {
    /// Helper to grab a piece of localized output text and do substitutions %1 .... %n
    static func localizedOutput(_ key: L10n.Output, _ subs: Any...) -> Localized<String> {
        Resources.shared.localizedOutput(key: key.rawValue, subs: subs)
    }
}

extension Dictionary where Key == String, Value: NulInitializable {
    /// Get the value for the language or an empty string if none
    func get(_ languageTag: String) -> Value {
        self[languageTag] ?? Value()
    }
}

// MARK: String-like utilities

extension Dictionary: Appendable where Key == String, Value: Appendable & NulInitializable {
    public static func +(lhs: Self, rhs: Self) -> Self {
        var out = Localized<Value>()
        lhs.forEach { key, val in
            out[key] = val + rhs.get(key)
        }
        return out
    }

    public static func +(lhs: Self, rhs: String) -> Self {
        lhs.mapValues { $0 + rhs }
    }
}

extension Localized: Comparable where Key == String, Value: Comparable & NulInitializable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let defaultTag = Localizations.shared.main.tag
        return lhs.get(defaultTag) < rhs.get(defaultTag)
    }
}

extension Array where Element == Localized<String> {
    func joined(by: String) -> Element {
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

// MARK: Read localized files

extension Array where Element == Glob.Pattern {
    /// Interpret the globs and seek out localized markdown files.
    /// Key of returned dictionary is the basename of the localized file, without the ".md".
    func readLocalizedMarkdownFiles() throws -> [String : Localized<Markdown>] {
        var files = [String: Localized<Markdown>]()
        try forEach { globPattern in
            logDebug("Glob: Searching for files using '\(globPattern)'")
            var count = 0
            try Glob.files(globPattern).forEach { url in
                let filename = url.lastPathComponent
                guard filename.lowercased().hasSuffix(".md") else {
                    logDebug("Glob: Ignoring \(url.path), wrong suffix.")
                    return
                }
                let basename = String(filename.dropLast(3 /*.md*/))
                guard files[basename] == nil else {
                    logWarning(.wrnDuplicateGlobfile, filename, url.path)
                    return
                }
                files[basename] = try Localized<Markdown>(localizingFile: url)
                count += 1
            }
            if count == 0 {
                logWarning(.wrnEmptyGlob, globPattern)
            } else {
                logDebug("Glob: Found \(count) files.")
            }
        }
        return files
    }
}

extension Localized where Key == String, Value == Markdown {
    /// Initialize a full localized hash of URLs for a file, using a localization-specific version
    /// if available.
    init(localizingFile url: URL) throws {
        self = try Localized<URL>(localizingFile: url)
            .mapValues { Markdown(try String(contentsOf: $0)) }
    }
}

extension Localized where Key == String, Value == URL {
    /// Initialize a full localized hash of URLs for a file, using a localization-specific version
    /// if available, assuming the original URL is for the system main localization.
    init(localizingFile url: URL) {
        self.init(localizingFile: url, languageTag: Localizations.shared.main.tag)
    }

    /// Initialize a full localized hash of URLs for a file, using a localization-specific version
    /// if available, using the original URL for the given language tag.
    init(localizingFile url: URL, languageTag: String) {
        self.init()
        let locs = Localizations.shared

        let filename = url.lastPathComponent
        let directory = url.deletingLastPathComponent()

        locs.all.forEach { loc in
            guard loc.tag != languageTag else {
                self[loc.tag] = url
                return
            }

            let locURL = directory
                .appendingPathComponent(loc.tag)
                .appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: locURL.path) {
                self[loc.tag] = locURL
            } else {
                // hmm should this fall back to system.main first?
                logDebug("Missing localization '\(loc.tag)' for \(url.path), using default \(languageTag).")
                self[loc.tag] = url
            }
        }
    }
}
