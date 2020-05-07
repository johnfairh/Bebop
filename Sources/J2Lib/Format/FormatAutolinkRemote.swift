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
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: mapping)

            guard let url = urlOpt.value else {
                throw J2Error(.errCfgRemoteUrl)
            }
            if !moduleOpt.value.isEmpty {
                return Source(url: url, modules: moduleOpt.value)
            }
            do {
                logDebug("Format: Trying for site.json to identify remote site content")
                let siteRecord = try GenSiteRecord.fetchRecord(from: url)
                return Source(url: url, modules: siteRecord.modules)
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

    /// Search json is a dict of keyed URLs to these structures
    struct SearchValue: Decodable {
        let name: String
        let parent_name: String?
    }

    typealias SearchIndex = [String:SearchValue]

    /// Thing we hold in memory
    final class Entry {
        let urlPath: String
        var children: [String: Entry]
        let parentName: String?
        weak var parent: Entry?

        init(urlPath: String, parentName: String?) {
            self.urlPath = urlPath
            self.parentName = parentName
            self.children = [:]
        }

        /// Navigate down the tree, return if run out of name pieces
        func lookup(namePieces: ArraySlice<String>) -> Entry? {
            guard let first = namePieces.first else {
                return self
            }
            return children[first]?.lookup(namePieces: namePieces.dropFirst())
        }
    }

    final class ModuleIndex {
        let topTypes: [String : Entry]
        let baseURL: URL

        init(baseURL: URL, searchIndex: SearchIndex) {
            var workingIndex = [String : Entry]()

            // Index the entries by name
            searchIndex.forEach {
                workingIndex[$0.value.name] =
                    Entry(urlPath: $0.key, parentName: $0.value.parent_name)
            }

            // Build the parent graph
            workingIndex.forEach { (entName, ent) in
                if let parentName = ent.parentName,
                    let parent = workingIndex[parentName] {
                    ent.parent = parent
                    parent.children[entName] = ent
                }
            }

            // Keep only top-level types
            self.topTypes = workingIndex.filter { $0.1.parent == nil }
            self.baseURL = baseURL
        }

        /// Walk a hierarchical (dot-separated) name down the tree
        func lookup(pieces: [String]) -> URL? {
            guard let firstEntry = topTypes[pieces[0]],
                let finalEntry = firstEntry.lookup(namePieces: pieces.dropFirst()) else {
                return nil
            }
            return baseURL.appendingPathComponent(finalEntry.urlPath)
        }
    }

    var moduleIndices = [ModuleIndex]()
    var indiciesByModule = [String: ModuleIndex]()

    func buildIndex() {
        sources
            .sorted(by: { $0.url.absoluteString < $1.url.absoluteString })
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
                logWarning("Failed to build remote autolink index for \(source): \(error).")
            }
        }
    }

    // MARK: Query

    /// If we have a module just go there, otherwise go through them all
    func lookup(module: String?, pieces: [String]) -> URL? {
        if let module = module {
            guard let moduleIndex = indiciesByModule[module] else {
                return nil
            }
            return moduleIndex.lookup(pieces: pieces)
        }
        for mIndex in moduleIndices {
            if let url = mIndex.lookup(pieces: pieces) {
                return url
            }
        }
        return nil
    }

    // MARK: API

    func autolink(hierarchicalName name: String) -> Autolink? {
        guard !sources.isEmpty else {
            return nil
        }
        if moduleIndices.isEmpty {
            buildIndex()
        }
        return nil
    }
}
