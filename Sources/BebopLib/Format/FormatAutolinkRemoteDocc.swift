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
final class FormatAutolinkRemoteDocc: RemoteAutolinkerProtocol {
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

            /// ignore stuff with weird 'types' that don't correspond to code things.
            var isLinkTarget: Bool {
                type.map { !Self.badTypes.contains($0) } ?? false
            }

            /// Extract parts of the symbol path
            var linkPathInfo: (module: String, symbol: String, suffix: String)? {
                guard let path,
                      isLinkTarget,
                      let match = path.re_match(#"^/documentation/(\S+?)/(\S+?)(?:-(\S+))?$"#) else {
                    return nil
                }
                return (module: match[1], symbol: match[2], suffix: match[3])
            }

            /// pre-order
            func forEach(_ iter: (Node) -> Void) {
                iter(self)
                children.map { $0.forEach { $0.forEach(iter) } }
            }
        }

        struct Languages: Decodable {
            let swift: [Node]?
        }

        let interfaceLanguages: Languages

        func forEach(_ iter: (Node) -> Void) {
            interfaceLanguages.swift.map { $0.forEach { $0.forEach(iter) } }
        }

        init(url: URL) throws {
            logDebug("Format: building docc lookup index from \(url.absoluteString)")
            let data = try url.appendingPathComponent("index/index.json").fetch()
            self = try JSONDecoder().decode(Self.self, from: data)
        }
    }

    /// Because the DocC nodes come in with full paths we don't bother treeifying this, just chuck all the symbols
    /// that are recognized into a per-module bucket.
    ///
    /// The module name itself is important because of the ambiguity in the written link.
    ///
    /// Docc 'solves' the ambiguous symbol name problem using a hash suffix or a type cookie.  We've lost this
    /// by the time we get down here - should rework autolink from the top to preserver them really.  Can offer
    /// better behaviour than Apple by linking to something if the suffix is missing.
    struct Module {
        /// module name, lower case
        let name: String
        /// docc base url, ends in 'documentation/<lower-case-module-name>'
        let baseURL: URL
        /// symbols in docc-format (/ not ., lower-case) that can be used directly as URLs
        var simpleSymbols: Set<String>
        /// keys are docc-format, values are suffix  required to make it a URL eg "1xom4" or "swift.type.property" -- the hyphen is not included
        var suffixedSymbols: [String : String]

        init(name: String, siteURL: URL) {
            self.name = name
            self.baseURL = siteURL.appendingPathComponent("documentation/\(name)")
            self.simpleSymbols = []
            self.suffixedSymbols = [:]
        }

        mutating func add(symbol: String, suffix: String) {
            if suffix.isEmpty {
                simpleSymbols.insert(symbol)
            } else {
                suffixedSymbols[symbol] = suffix
            }
        }

        /// `name` is in bebop format as the user wrote it
        func lookup(name: String) -> URL? {
            let doccName = name.asDoccName
            let path: String
            if simpleSymbols.contains(doccName) {
                path = doccName
            } else if let suffix = suffixedSymbols[doccName] {
                path = "\(doccName)-\(suffix)"
            } else {
                return nil
            }
            return baseURL.appendingPathComponent(path)
        }
    }

    /// Index is module name, lower case
    var modules: [String: Module] = [:]

    /// Pull down the index JSON and augment our lookups.  Too late to throw if anything is wrong, just wrn.
    func buildIndex(url: URL) {
        precondition(modules.isEmpty)
        do {
            try RenderIndexJSON(url: url).forEach { node in
                guard let parts = node.linkPathInfo else {
                    return
                }
                modules[parts.module, default: Module(name: parts.module, siteURL: url)]
                    .add(symbol: parts.symbol, suffix: parts.suffix)
            }
        } catch {
            logWarning("Couldn't decode Docc RenderIndex JSON from \(url.absoluteString): \(error)") // XXX
        }
    }

    /// `name` is an identifier in J2 format, ie. with dots, and we don't know what module it's in
    func lookup(name: String) -> URL? {
        for module in modules.values {
            if let url = module.lookup(name: name) {
                return url
            }
        }
        return nil
    }

    /// `name` is an identifier in J2 format, ie. with dots, and cased however the user wrote it
    /// `module` is cased however the user wrote it
    func lookup(name: String, in moduleName: String) -> URL? {
        guard let module = modules[moduleName.lowercased()] else {
            return nil
        }
        return module.lookup(name: name)
    }
}

private extension String {
    var asDoccName: String {
        replacingOccurrences(of: ".", with: "/").lowercased()
    }
}
