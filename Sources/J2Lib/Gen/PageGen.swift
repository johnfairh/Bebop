//
//  PageGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `PageGen` is a simple component that takes the formatted docs forest and converts them
/// into the consolidated data structure that can spit out data for the page renderer.
///
public struct PageGen: Configurable {
    public init(config: Config) {
        config.register(self)
    }

    public func generatePages(items: [Item]) throws -> GenData {
        let meta = GenData.Meta(version: Version.j2libVersion)
        let toc = generateToc(items: items)

        let pageVisitor = PageVisitor()
        pageVisitor.walk(items: items)

        return GenData(meta: meta, toc: toc, pages: pageVisitor.pages)
    }

    // MARK: Table of contents

    func generateToc(items: [Item]) -> [GenData.TocEntry] {
        items.compactMap { toplevelItem -> GenData.TocEntry? in
            guard toplevelItem.showInToc != .no else {
                return nil // readme
            }
            return GenData.TocEntry(url: toplevelItem.url,
                                     title: toplevelItem.title,
                                     children: toplevelItem.children.compactMap { generateSubToc(item: $0) })
        }
    }

    func generateSubToc(item: Item) -> GenData.TocEntry? {
        guard item.showInToc == .yes else {
            return nil
        }
        return GenData.TocEntry(url: item.url,
                                 title: item.title,
                                 children: item.children.compactMap { generateSubToc(item: $0) })
    }
}

// MARK: Page data

final class PageVisitor: ItemVisitor {
    var pages = [GenData.Page]()

    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.renderAsPage {
            pages.append(GenData.Page(url: defItem.url, title: defItem.title))
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        pages.append(GenData.Page(url: groupItem.url, title: groupItem.title))
    }
}
