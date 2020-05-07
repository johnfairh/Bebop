//
//  FormatAutolinkRemote.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Yams

/// Support for autolinking to other docs sites.
///
/// Attempt to support traditional jazzy and j2 as well via the search.json -- not perfect but
/// should be close enough.
final class FormatAutolinkRemote: Configurable {
    let remoteAutolinkOpt = YamlOpt(y: "remote_autolink")

    init(config: Config) {
        config.register(self)
    }

    // MARK: Config

    struct Source {
        let url: URL
        let modules: [String]
    }
    var sources = [Source]()

    struct SourceParser {
        let urlOpt = URLOpt(y: "url")
        let moduleOpt = StringListOpt(y: "modules")

        func parse(mapping: Yams.Node.Mapping) throws -> Source {
            guard let url = urlOpt.value else {
                throw J2Error(.errCfgRemoteUrl)
            }
            if !moduleOpt.value.isEmpty {
                return Source(url: url, modules: moduleOpt.value)
            }
            do {
                logDebug("Format: Trying for site.json to identify remote site content")
                let siteRecord = try GenSiteRecord.fetchRecord(from: url)
                return Source(url: url, modules: siteRecord.moduleNames)
            } catch {
                throw J2Error(.errCfgRemoteModules, url.absoluteString, error)
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

    // MARK: Build

    // MARK: Query

    // MARK: API

    func autolink(hierarchicalName name: String) -> Autolink? {
        nil
    }
}
