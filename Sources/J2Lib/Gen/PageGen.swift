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
        let meta = GenData.Meta(version: Version.j2libVersion)

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
            // XXX for jazzy compat, sort outside of depth 0 unless custom cats???
        }

        return doGenerate(items: items, depth: 0)
    }
}

// MARK: Page data

final class PageVisitor: ItemVisitorProtocol {
    /// All pages
    var pages = [GenData.Page]()

    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.renderAsPage {
            pages.append(GenData.Page(
                defURL: defItem.url,
                title: defItem.title,
                abstract: defItem.documentation.abstract?.html,
                overview: defItem.documentation.overview?.html,
                swiftDeclaration: Html(defItem.swiftDeclaration.declaration),
                topics: buildTopics(item: defItem)))
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        pages.append(GenData.Page(groupURL: groupItem.url,
                                  title: groupItem.title,
                                  overview: nil,
                                  topics: buildTopics(item: groupItem)))
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: guideItem.url,
                                  title: guideItem.title,
                                  isReadme: false,
                                  overview: nil))
    }

    func visit(readmeItem: ReadmeItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: readmeItem.url,
                                  title: readmeItem.title,
                                  isReadme: true,
                                  overview: nil))
    }

    func buildTopics(item: Item) -> [GenData.Topic] {
        var topics = [GenData.Topic]()
        let itemVisitor = ItemVisitor()
        var currentTopic: Topic? = nil

        let uniquer = StringUniquer()

        func endTopic() {
            if let currentTopic = currentTopic {
                let slugRoot = currentTopic.title.markdown.get(Localizations.shared.main.tag).md
                topics.append(GenData.Topic(title: currentTopic.title,
                                            anchorId: uniquer.unique("tpc_" + slugRoot.slugged),
                                            body: currentTopic.body?.html,
                                            items: itemVisitor.resetItems()))
            }
        }

        item.children.forEach { child in
            if child.topic !== currentTopic {
                endTopic()
                currentTopic = child.topic
            }
            itemVisitor.walkOne(item: child)
        }
        endTopic()
        return topics
    }
}

/// Visitor to construct an Item that can appear inside a topic on a page.
class ItemVisitor: ItemVisitorProtocol {
    var items = [GenData.Item]()

    func resetItems() -> [GenData.Item] {
        defer { items = [] }
        return items
    }

    func visit(defItem: DefItem, parents: [Item]) {
        // not masochistic enough to do this in templates...
        let swiftTitleHtml = defItem.swiftDeclaration.namePieces.wrappingOther(before: #"<span class="j2-item-secondary">"#, after: "</span>")
        items.append(GenData.Item(
            anchorId: defItem.slug,
            flatTitle: .init(unlocalized: defItem.swiftDeclaration.namePieces.flattened),
            swiftTitleHtml: Html(swiftTitleHtml),
            dashType: defItem.defKind.dashName,
            url: defItem.renderAsPage ? defItem.url : nil))
    }

    /// Guides and Groups are simple, just a link really.
    func visitFlat(item: Item) {
        items.append(GenData.Item(
            anchorId: item.slug,
            flatTitle: item.title,
            swiftTitleHtml: nil,
            dashType: nil,
            url: item.url))
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        visitFlat(item: groupItem)
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        visitFlat(item: guideItem)
    }
}
