//
//  PageGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `GenPages` is a simple component that takes the formatted docs forest and converts them
/// into the consolidated data structure that can spit out data for the page renderer.
///
public struct GenPages: Configurable {
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
                                        title: item.swiftTitle ?? .init(unlocalized: "SWIFT"),
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
                title: defItem.swiftTitle ?? .init(unlocalized: "SWIFT"),
                breadcrumbs: buildBreadcrumbs(parents: parents),
                definition: defItem.asGenDef,
                topics: buildTopics(item: defItem)))
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        pages.append(GenData.Page(groupURL: groupItem.url,
                                  title: groupItem.title,
                                  breadcrumbs: buildBreadcrumbs(parents: parents),
                                  content: nil,
                                  topics: buildTopics(item: groupItem)))
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: guideItem.url,
                                  title: guideItem.title,
                                  breadcrumbs: buildBreadcrumbs(parents: parents),
                                  isReadme: false,
                                  content: guideItem.content.html))
    }

    func visit(readmeItem: ReadmeItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: readmeItem.url,
                                  title: readmeItem.title,
                                  breadcrumbs: [],
                                  isReadme: true,
                                  content: readmeItem.content.html))
    }

    /// Breadcrumbs for a page.
    /// Don't include the root: that's the readme/index.html handled separately.
    /// Don't include ourselves: that's not a link and is handled separately
    func buildBreadcrumbs(parents: [Item]) -> [GenData.Breadcrumb] {
        parents.map {
            let title = $0.swiftTitle ?? .init(unlocalized: "SWIFT")
            return GenData.Breadcrumb(title: title, url: $0.url)
        }
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

// MARK: Items

extension DefItem {
    func namePieces(for language: DefLanguage) -> [DeclarationPiece] {
        switch language {
        case .swift: return swiftDeclaration!.namePieces
        case .objc: return objCDeclaration!.namePieces
        }
    }

    var primaryNamePieces: [DeclarationPiece] {
        namePieces(for: primaryLanguage)
    }

    var secondaryNamePieces: [DeclarationPiece]? {
        secondaryLanguage.flatMap { namePieces(for: $0) }
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
        let titleHtmls = [defItem.primaryNamePieces, defItem.secondaryNamePieces].map {
            $0.flatMap {
                Html($0.wrappingOther(before: #"<span class="j2-item-secondary">"#, after: "</span>"))
            }
        }
        items.append(GenData.Item(
            anchorId: defItem.slug,
            flatTitle: .init(unlocalized: defItem.primaryNamePieces.flattened),
            primaryLanguage: defItem.primaryLanguage,
            secondaryLanguage: defItem.secondaryLanguage,
            primaryTitleHtml: titleHtmls[0],
            secondaryTitleHtml: titleHtmls[1],
            dashType: defItem.defKind.dashName,
            url: defItem.renderAsPage ? defItem.url : nil,
            def: defItem.asGenDef))
    }

    /// Guides and Groups are simple, just a link really.
    func visitFlat(item: Item) {
        items.append(GenData.Item(
            anchorId: item.slug,
            title: item.swiftTitle!, // XXX this one can be flat title
            url: item.url))
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        visitFlat(item: groupItem)
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        visitFlat(item: guideItem)
    }
}

extension DefItem {
    var asGenDef: GenData.Def {
        GenData.Def(deprecation: deprecationNotice?.html,
                    availability: swiftDeclaration?.availability ?? [],
                    abstract: documentation.abstract?.html,
                    overview: documentation.overview?.html,
                    swiftDeclaration: swiftDeclaration.flatMap { Html($0.declaration) },
                    objCDeclaration: objCDeclaration.flatMap { Html($0.declaration) },
                    params: documentation.parameters.map { docParam in
                        GenData.Param(name: docParam.name, description: docParam.description.html)
                    },
                    returns: documentation.returns?.html)
    }
}
