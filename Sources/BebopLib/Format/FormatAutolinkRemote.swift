//
//  FormatAutolinkRemote.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import Yams

/// Support for autolinking to other docs sites.
///
/// Attempt to support traditional jazzy and bebop as well via the search.json -- not perfect but
/// should be close enough.
///
/// Attempt to support DocC too by slurping its index JSON.
final class FormatAutolinkRemote: Configurable {
    let remoteJazzy = FormatAutolinkRemoteJazzy()
    let remoteDocc = FormatAutolinkRemoteDocc()

    let remoteAutolinkOpt = YamlOpt(y: "remote_autolink")

    init(config: Config) {
        config.register(self)
    }

    // MARK: Config

    struct Source {
        enum Kind: Equatable {
            /// Jazzy-style docs have a search.json that can't be relied on to have module info,
            /// so the modules must be set on the CLI or read from a (Bebop) json file
            case jazzy(modules: [String])
            /// Docc docs have an index that contains module info
            case docc
        }
        let url: URL
        let kind: Kind
    }
    var sources = [Source]()

    struct SourceParser {
        let urlOpt = URLOpt(y: "url")
        let moduleOpt = StringListOpt(y: "modules")

        func parse(mapping: Yams.Node.Mapping) throws -> Source {
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            guard let url = urlOpt.value else {
                throw BBError(.errCfgRemoteUrl)
            }
            guard moduleOpt.value.isEmpty else {
                return Source(url: url.withTrailingSlash, kind: .jazzy(modules: moduleOpt.value))
            }
            var jError: Error?
            do {
                logDebug("Format: Trying for site.json to identify remote site content")
                let siteRecord = try GenSiteRecord.fetchRecord(from: url)
                return Source(url: url, kind: .jazzy(modules: siteRecord.modules))
            } catch {
                jError = error
            }
            do {
                try FormatAutolinkRemoteDocc.checkDoccWebsite(url: url)
                return Source(url: url, kind: .docc)
            } catch {
                throw BBError(.errCfgRemoteModules, url.absoluteString, jError!, error)
            }
        }
    }

    /// Figure out the source info up front, wait until we're invoked to grab the search info and build the trees
    func checkOptions() throws {
        if let remoteAutolinkYaml = remoteAutolinkOpt.value {
            logDebug("Format: start parsing remote_autolink")
            sources = try remoteAutolinkYaml.checkSequence(context: "remote_autolink").map {
                try SourceParser().parse(mapping: $0.checkMapping(context: "remote_autolink[]"))
            }
            logDebug("Group: done parsing remote_autolink: \(sources)")
        }
    }

    // MARK: Index

    private var indexed = false

    func buildIndex() {
        guard !indexed else {
            return
        }
        indexed = true
        sources
            .sorted { $0.url.absoluteString < $1.url.absoluteString }
            .forEach { source in
                switch source.kind {
                case .jazzy(modules: let modules):
                    remoteJazzy.buildIndex(url: source.url, modules: modules)
                case .docc:
                    remoteDocc.buildIndex(url: source.url)
                }
            }
    }

    // MARK: API

    /// Build the index on first call, search for the name.
    func autolink(name: String) -> Autolink? {
        guard !sources.isEmpty else {
            return nil
        }

        buildIndex()

        logDebug("Format: remote autolink attempt for \(name)")

        let remotes: [any RemoteAutolinkerProtocol] = [remoteJazzy, remoteDocc]

        // First assume the name doesn't start with a module name.
        if let url = remotes.lookup(name: name) {
            logDebug("Format: resolved to \(url.absoluteString)")
            Stats.inc(.autolinkRemoteSuccess)
            return Autolink(url: url, text: name)
        }

        // Now try assuming the first name piece is a module name.
        if let matches = name.re_match(#"^(.*?)\.(.*)$"#),
           !matches[2].isEmpty,
           let url = remotes.lookup(name: matches[2], in: matches[1]) {
            logDebug("Format: resolved to \(url.absoluteString)")
            Stats.inc(.autolinkRemoteSuccessModule)
            return Autolink(url: url, text: name)
        }

        logDebug("Format: unable to resolve")
        Stats.inc(.autolinkRemoteFailure)

        return nil
    }
}

extension URL {
    /// This makes relative URL calculations come off properly (rfc2396)
    var withTrailingSlash: URL {
        let str = absoluteString
        if absoluteString.hasSuffix("/") {
            return self
        }
        return URL(string: "\(str)/")!
    }
}

// MARK: Stuff to abstract over jazzy/docc/??? for lookup

protocol RemoteAutolinkerProtocol {
    func lookup(name: String) -> URL?
    func lookup(name: String, in: String) -> URL?
}

extension Array: RemoteAutolinkerProtocol where Element == any RemoteAutolinkerProtocol {
    private func iter(with: (Element) -> URL?) -> URL? {
        for e in self {
            if let url = with(e) {
                return url
            }
        }
        return nil

    }

    func lookup(name: String) -> URL? {
        iter { $0.lookup(name: name) }
    }

    func lookup(name: String, in module: String) -> URL? {
        iter { $0.lookup(name: name, in: module) }
    }
}
