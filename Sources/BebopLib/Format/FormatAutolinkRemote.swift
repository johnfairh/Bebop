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
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            guard let url = urlOpt.value else {
                throw BBError(.errCfgRemoteUrl)
            }
            if !moduleOpt.value.isEmpty {
                return Source(url: url.withTrailingSlash, modules: moduleOpt.value)
            }
            do {
                logDebug("Format: Trying for site.json to identify remote site content")
                let siteRecord = try GenSiteRecord.fetchRecord(from: url)
                return Source(url: url, modules: siteRecord.modules)
            } catch {
                throw BBError(.errCfgRemoteModules, url.absoluteString, error)
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

    /// Search json is a dict of keyed URLs to these structures
    struct SearchValue: Decodable {
        let name: String
        let parent_name: String?
    }

    typealias SearchIndex = [String:SearchValue]

    /// Build a tree of search index entries reflecting the name hierarchy
    final class Entry {
        let urlPath: String
        var children: [String: Entry]
        weak var parent: Entry?

        init(urlPath: String, parent: Entry? = nil) {
            self.urlPath = urlPath
            self.children = [:]
            self.parent = parent
        }
    }

    /// Map from name to url path for a particular remote site - flattened entry tree
    final class ModuleIndex {
        let map: [String : String]
        let baseURL: URL

        init(baseURL: URL, searchIndex: SearchIndex) {
            var index = [String : Entry]()

            // This is horrible because of naming in the search format:
            // simpler single-pass methods end up with method etc. name collisions.

            // Sort for reproducibility.
            var sortedIndex = searchIndex.sorted { $0.0 < $1.0 }

            // First pass: stuff without a parent
            sortedIndex = sortedIndex.filter { (urlPath, searchValue) in
                if searchValue.parent_name == nil {
                    index[searchValue.name] = Entry(urlPath: urlPath)
                    return false
                }
                return true
            }

            // Now repeatedly try and parent entries, building up the graph
            // from the roots.  Approximately.
            var changes = false
            while true {
                sortedIndex = sortedIndex.filter { (urlPath, searchValue) in
                    guard let parentName = searchValue.parent_name,
                        let parentEntry = index[parentName] else {
                            return true // keep for next time
                    }
                    // overwrite any existing child with the same name
                    let entry = Entry(urlPath: urlPath, parent: parentEntry)
                    let entryName = searchValue.name
                    parentEntry.children[entryName] = entry
                    // special case Swift functions
                    if entryName.contains("(") {
                        parentEntry.children[entryName.re_sub(#"\(.*\)"#, with: "(...)")] = entry
                    }
                    // don't overwrite an existing parent name candidate
                    if index[entryName] == nil {
                        index[entryName] = entry
                    }
                    changes = true
                    return false
                }
                if !changes {
                    break
                }
                changes = false
            }

            // Now flatten it
            var nameMap = [String: String]()

            func doEntry(_ entry: Entry, pathPieces: [String]) {
                nameMap[pathPieces.joined(separator: ".")] = entry.urlPath
                entry.children.forEach {
                    doEntry($1, pathPieces: pathPieces + [$0])
                }
            }

            index.forEach { (entryName, entry) in
                if entry.parent == nil {
                    doEntry(entry, pathPieces: [entryName])
                }
            }

            self.map = nameMap
            self.baseURL = baseURL
        }

        /// Just look up the name and build the full URL
        func lookup(name: String) -> URL? {
            guard let urlPath = map[name] else {
                return nil
            }

            return URLComponents(string: urlPath)?.url(relativeTo: baseURL)
        }
    }

    var moduleIndices = [ModuleIndex]()
    var indiciesByModule = [String: ModuleIndex]()

    func buildIndex() {
        sources
            .sorted { $0.url.absoluteString < $1.url.absoluteString }
            .forEach { source in
                do {
                    let searchURL = source.url.appendingPathComponent("search.json")
                    logDebug("Format: building lookup index from \(searchURL.path)")
                    let searchData = try searchURL.fetch()
                    let searchIndex = try JSONDecoder().decode(SearchIndex.self, from: searchData)
                    let moduleIndex = ModuleIndex(baseURL: source.url, searchIndex: searchIndex)
                    moduleIndices.append(moduleIndex)
                    source.modules.forEach {
                        indiciesByModule[$0] = moduleIndex
                    }
                } catch {
                    logWarning(.wrnRemoteSearch, source, error)
                }
            }
    }

    // MARK: API

    /// Build the index on first call, search for the name.
    /// Pretty sure there's %-encoding needed on these URLs.
    func autolink(name: String) -> Autolink? {
        guard !sources.isEmpty else {
            return nil
        }

        if moduleIndices.isEmpty {
            buildIndex()
        }

        logDebug("Format: remote autolink attempt for \(name)")

        // First assume the name doesn't start with a module name.
        // Go through each source trying to resolve.
        for mIndex in moduleIndices {
            if let url = mIndex.lookup(name: name) {
                logDebug("Format: resolved to \(url.absoluteString)")
                Stats.inc(.autolinkRemoteSuccess)
                return Autolink(url: url, text: name)
            }
        }

        // Now try assuming the first name piece is a module name.
        if let matches = name.re_match(#"^(.*?)\.(.*)$"#),
            let moduleIndex = indiciesByModule[matches[1]],
            !matches[2].isEmpty,
            let url = moduleIndex.lookup(name: matches[2]) {
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
