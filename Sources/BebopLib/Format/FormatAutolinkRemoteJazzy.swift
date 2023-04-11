//
//  FormatAutolinkRemoteJazzy.swift
//  BebopLib
//
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// Look up symbols in remote jazzy / bebop doc websites
/// This uses the `search.json` because jazzy websites will have it, rather than writing something
/// new. So this is all a bit creaky.
final class FormatAutolinkRemoteJazzy: RemoteAutolinkerProtocol {
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
                // Don't link to extensions of types instead of the actual types
                if urlPath.components(separatedBy: "/")
                    .map(\.localizedLowercase)
                    .contains("extensions") {
                    return false
                }
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

    func buildIndex(url: URL, modules: [String]) {
        do {
            let searchURL = url.appendingPathComponent("search.json")
            logDebug("Format: building jazzy lookup index from \(searchURL.path)")
            let searchData = try searchURL.fetch()
            let searchIndex = try JSONDecoder().decode(SearchIndex.self, from: searchData)
            let moduleIndex = ModuleIndex(baseURL: url, searchIndex: searchIndex)
            moduleIndices.append(moduleIndex)
            modules.forEach {
                indiciesByModule[$0] = moduleIndex
            }
        } catch {
            logWarning(.wrnRemoteSearch, url, error)
        }
    }

    func lookup(name: String) -> URL? {
        for mIndex in moduleIndices {
            if let url = mIndex.lookup(name: name) {
                return url
            }
        }
        return nil
    }

    func lookup(name: String, in module: String) -> URL? {
        if let moduleIndex = indiciesByModule[module],
           let url = moduleIndex.lookup(name: name) {
            return url
        }
        return nil
    }
}
