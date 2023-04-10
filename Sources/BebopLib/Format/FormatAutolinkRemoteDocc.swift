//
//  FormatAutolinkRemoteDocc.swift
//  BebopLib
//
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

///
/// Utils to enable smart-ish linking to Docc websites.
/// Only for Swift right now.
///
final class FormatAutolinkRemoteDocc: Configurable {
    /// See if a URL looks like a Docc website.  Simplest way is to check for the "availability index" which
    /// is a small binary plist (!?)
    static func checkDoccWebsite(url: URL) throws {
        logDebug("Format: sniffing \(url.absoluteString) for Docc")
        let availabilityIndex = try url.appendingPathComponent("index/availability.index").fetch()
        logDebug("Format: fetched availability index OK, \(availabilityIndex.count) bytes, probably DocC")
    }

    /// Wire-format structs for decoding the index.json
    struct RenderIndexJSON: Decodable {
        struct Node: Decodable {
            let path: String?
            // don't need title?
            let type: String? // spec says this is optional...
            let children: [Node]?

            static let badTypes: Set<String> = [
                "symbol", "module"
            ]

            /// ignore stuff without a path and weird 'types' that
            /// don't correspond to code things.
            var isLinkTarget: Bool {
                path != nil && type.map { !Self.badTypes.contains($0) } ?? false
            }

            var pathInfo: (module: String, symbol: String, suffix: String) {
                ("", "", "")
            }

            /// pre-order
            func forEach(_ iter: (Node) -> Void) {
                iter(self)
                children.map { $0.forEach { iter($0) } }
            }
        }

        struct Languages: Decodable {
            let swift: [Node]?
        }

        let interfaceLanguages: Languages

        init(url: URL) throws {
            let data = try url.appendingPathComponent("index/index.json").fetch()
            self = try JSONDecoder().decode(Self.self, from: data)
        }
    }

    /// Because the DocC nodes come in with full paths we don't bother treeifying this, just chuck all the symbols
    /// that are recognized into a per-module bucket.
    ///
    /// The module name itself is important because of the ambiguity in the written link.
    struct Module {
        /// module name, lower case
        let name: String
        /// docc base url, ends in 'documentation/<lower-case-module-name>'
        let baseURL: URL
        /// symbols in docc-format (/ not ., lower-case) that can be used directly as URLs
        var simpleSymbols: Set<String>
        /// keys are docc-format, values are extension required to make it a URL eg "1xom4" or "swift.type.property" -- the hyphen is not included
        var extendedSymbols: [String : String] // keys symbols in docc-form
    }

    /// Index is module name, lower case
    var modules: [String: Module] = [:]

    /// Pull down the index JSON and augment our lookups.  Too late to throw if anything is wrong, just wrn.
    func buildIndex(url: URL) {
        do {
            let json = try RenderIndexJSON(url: url)
        } catch {
            logWarning("Couldn't decode Docc RenderIndex JSON from \(url.absoluteString): \(error)") // XXX
        }
    }
}
