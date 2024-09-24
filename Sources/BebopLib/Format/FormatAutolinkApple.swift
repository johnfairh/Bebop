//
//  FormatAutolinkApple.swift
//  BebopLib
//
//  Copyright 2021 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// Autolinking to reference docs on apple.com.
///
/// Prior to Xcode 12.5 this used a database in Xcode to link over to apple.com.  This undocumented and
/// unsupported but very useful database was removed in Xcode 12.5 -- see commits prior to May 2021.
///
/// Instead we have a shonky manual map that needs updating as docs link to new places.
///
final class FormatAutolinkApple: Configurable {
    let disableOpt = BoolOpt(l: "no-apple-autolink")

    init(config: Config) {
        config.register(self)
    }

    // MARK: Load

    struct Module {
        let name: String
        let entries: [String : String]

        /// Each file is utf8, one line per appledoc url
        /// Each line split into fields with |
        /// First field is the case correct type name
        /// One field in the row: url is the downcased & slash-for-dot version of the type name
        /// N fields in the row: url is the last field, other fields are type/identifier names
        init?(url: URL) {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                logWarning("Something wrong with apple_doc module \(url.path)")
                return nil
            }

            name = url.lastPathComponent
            entries = .init(uniqueKeysWithValues: raw.split(separator: "\n")
                .map { String($0).strsplit("|") }
                .flatMap { words -> [(String, String)] in
                    let lastWord = words.last!
                    if words.count == 1 {
                        // special case for types, convert typename to URL path
                        return [(lastWord, lastWord.lowercased().replacingOccurrences(of: ".", with: "/"))]
                    }
                    // can be multiple names mapping to same URL path
                    return words.dropLast().map { ($0, lastWord) }
                })
            logDebug("Format: \(entries.count) entries for apple_doc module \(name)")
        }

        func urlPathFor(name symbol: String) -> String? {
            entries[symbol].flatMap { "\(name.lowercased())/\($0)" }
        }
    }

    private(set) var modules = [String : Module]()
    private(set) var moduleSearchOrder = [String]()

    func loadModules() {
        guard modules.isEmpty else { return }

        guard let resourceURL = Resources.shared.bundle.resourceURL else {
            preconditionFailure("Resources corrupt, can't find resource URL")
        }
        resourceURL.appendingPathComponent("apple_doc")
            .filesMatching(.all)
            .compactMap { Module(url: $0) }
            .forEach {
                modules[$0.name] = $0
            }
        let fixedModules = ["Swift", "ObjectiveC"]
        moduleSearchOrder = fixedModules + (modules.keys
            .filter { !fixedModules.contains($0) }
            .sorted())
    }

    // MARK: Query

    func find(name: String, in moduleName: String) -> String? {
        modules[moduleName]?.urlPathFor(name: name)
    }

    func find(name: String) -> String? {
        for moduleName in moduleSearchOrder {
            if let path = find(name: name, in: moduleName) {
                return path
            }
        }
        return nil
    }

    // MARK: API

    private struct AutolinkText {
        let pieces: [String]
        let language: DefLanguage?

        /// Decompose an autolink-syntax identifier into pieces relevant to lookup and a hint
        /// to what language it is.
        init(autolinkText: String, language: DefLanguage?) {
            if autolinkText.isObjCClassMethodName {
                // ObjC method.  Want classname.restofname - discard +-
                self.pieces = autolinkText.hierarchical.re_sub("[-+]", with: "").strsplit(".")
                self.language = .objc
            } else {
                // Some Swift identifier or ObjC type
                self.pieces = autolinkText.strsplit(".")
                self.language = language
            }
        }

        /// Assuming the text could be a module-qualified name
        var moduleQualified: (module: String, name: String)? {
            guard pieces.count > 1 else {
                return nil
            }
            return (pieces[0], pieces.dropFirst().joined(separator: "."))
        }

        /// The entire name as written (massaged for ObjC)
        var unqualified: String {
            pieces.joined(separator: ".")
        }
    }

    /// Try to resolve `text` against the DB of Apple modules.
    /// No caching.
    func autolink(text: String, language: DefLanguage? = nil) -> Autolink? {
        guard !disableOpt.value else {
            return nil
        }

        guard let initial = text.first, !initial.isLowercase else {
            return nil
        }

        loadModules()

        let alText = AutolinkText(autolinkText: text, language: language)

        let link = (alText.moduleQualified.flatMap {
            find(name: $0.name, in: $0.module)
        } ?? find(name: alText.unqualified)).flatMap {
            makeLink(text: text, urlPath: $0, language: alText.language)
        }

        if link == nil {
            logDebug("AutolinkApple2: failed to match '\(text)'.")
            Stats.inc(.autolinkAppleFailure)
        } else {
            logDebug("AutolinkApple2: matched \(text) to \(link!.primaryURL)")
            Stats.inc(.autolinkAppleSuccess)
        }
        return link
    }

    /// Generate the link, best-effort c/swift versions

    static let APPLE_DOCS_BASE_URL = "https://developer.apple.com/documentation/"

    private func makeLink(text: String, urlPath: String, language: DefLanguage?) -> Autolink {
        let urlString = Self.APPLE_DOCS_BASE_URL + urlPath
        let mainLanguage = language ?? .swift
        let otherLanguage = mainLanguage.otherLanguage
        let mainURLString = urlString + "?language=\(mainLanguage.rawValue)"
        let otherURLString = urlString + "?language=\(otherLanguage.rawValue)"
        let escapedText = text.htmlEscaped
        let mainClasses = mainLanguage.cssName
        let otherClasses = "\(otherLanguage.cssName) j2-secondary"

        let html = #"<a href="\#(mainURLString)" class="\#(mainClasses)"><code>\#(escapedText)</code></a>"# +
                   #"<a href="\#(otherURLString)" class="\#(otherClasses)"><code>\#(escapedText)</code></a>"#

        return Autolink(url: mainURLString, html: html)
    }
}

private extension String {
    func strsplit(_ separator: Element) -> [String] {
        split(separator: separator).map(String.init)
    }
}
