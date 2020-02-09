//
//  PageGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `PageGen` is a simple component that takes the formatted docs forest and converts them
/// into a flat data structure very close to what's required by the page renderer.
///
public struct PageGen: Configurable {
    public init(config: Config) {
        config.register(self)
    }

    public func generatePages(items: [Item]) throws -> DocsData {
        let meta = DocsData.Meta(version: Version.j2libVersion)
        let toc = generateToc(items: items)
        return DocsData(meta: meta, toc: toc, pages: [])
    }

    func generateToc(items: [Item]) -> [DocsData.TocEntry] {
        items.compactMap { toplevelItem -> DocsData.TocEntry? in
            guard toplevelItem.showInToc != .no else {
                return nil // readme
            }
            return DocsData.TocEntry(url: toplevelItem.url,
                                     title: toplevelItem.title,
                                     children: toplevelItem.children.compactMap { generateSubToc(item: $0) })
        }
    }

    func generateSubToc(item: Item) -> DocsData.TocEntry? {
        guard item.showInToc == .yes else {
            return nil
        }
        return DocsData.TocEntry(url: item.url,
                                 title: item.title,
                                 children: item.children.compactMap { generateSubToc(item: $0) })
    }
}
