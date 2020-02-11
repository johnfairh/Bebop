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
        let toc = generateToc(items: items)

        let pageVisitor = PageVisitor()
        pageVisitor.walk(items: items)
        let meta = GenData.Meta(version: Version.j2libVersion,
                                moduleNames: pageVisitor.moduleNames)

        return GenData(meta: meta, toc: toc, pages: pageVisitor.pages)
    }

    // MARK: Table of contents

    func generateToc(items: [Item]) -> [GenData.TocEntry] {
        func doGenerate(items: [Item], depth: Int) -> [GenData.TocEntry] {
            items.compactMap { item in
                guard item.showInToc == .yes ||
                    (item.showInToc == .atTopLevel && depth < 2) else {
                    return nil
                }
                return GenData.TocEntry(url: item.url,
                                        title: item.title,
                                        children: doGenerate(items: item.children, depth: depth + 1))
            }
        }

        return doGenerate(items: items, depth: 0)
    }
}

// MARK: Page data

final class PageVisitor: ItemVisitor {
    /// All pages
    var pages = [GenData.Page]()
    /// Some module name - used to generate default headings, nothing semantic
    var moduleNames = Set<String>()

    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.renderAsPage {
            pages.append(GenData.Page(url: defItem.url, title: defItem.title, isGuide: false))
        }
        moduleNames.insert(defItem.moduleName)
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        pages.append(GenData.Page(url: groupItem.url, title: groupItem.title, isGuide: false))
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        pages.append(GenData.Page(url: guideItem.url, title: guideItem.title, isGuide: true))
    }
}
