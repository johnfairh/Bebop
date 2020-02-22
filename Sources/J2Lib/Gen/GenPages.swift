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
        let languageVisitor = LanguageVisitor()
        languageVisitor.walk(items: items)
        let languages = Array(languageVisitor.languages)

        let pageVisitor = PageVisitor(languages: languages)
        pageVisitor.walk(items: items)
        let meta = GenData.Meta(version: Version.j2libVersion,
                                languages: languages)

        let tocs = languages.map {
            generateToc(items: items, language: $0)
        }

        return GenData(meta: meta, tocs: tocs, pages: pageVisitor.pages)
    }

    // MARK: Table of contents

    func generateToc(items: [Item], language: DefLanguage) -> [GenData.TocEntry] {
        func doGenerate(items: [Item], depth: Int) -> [GenData.TocEntry] {
            items.compactMap { item in
                guard item.showInToc == .yes ||
                    (item.showInToc == .atTopLevel && depth < 2) else {
                    return nil
                }
                guard let title = item.title(for: language) else {
                    return nil
                }
                // Groups themselves are bilingual but don't show if empty
                if item.kind == .group &&
                    item.children.allSatisfy({ $0.title(for: language) == nil }) {
                    return nil
                }
                return GenData.TocEntry(url: item.url,
                                        title: title,
                                        children: doGenerate(items: item.children, depth: depth + 1))
            }
            // XXX for jazzy compat, sort outside of depth 0 unless custom cats???
        }

        return doGenerate(items: items, depth: 0)
    }
}

// MARK: Page data

final class LanguageVisitor: ItemVisitorProtocol {
    /// Languages found
    var languages = Set<DefLanguage>()

    func visit(defItem: DefItem, parents: [Item]) {
        languages.insert(defItem.primaryLanguage)
        if let secondaryLanguage = defItem.secondaryLanguage {
            languages.insert(secondaryLanguage)
        }
    }
}

final class PageVisitor: ItemVisitorProtocol {
    let languages: [DefLanguage]
    init(languages: [DefLanguage]) {
        self.languages = languages
    }

    /// All pages
    var pages = [GenData.Page]()

    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.renderAsPage {
            pages.append(GenData.Page(
                defURL: defItem.url,
                primaryTitle: defItem.primaryTitle,
                primaryLanguage: defItem.primaryLanguage,
                secondaryTitle: defItem.secondaryTitle,
                breadcrumbs: buildBreadcrumbs(item: defItem, parents: parents),
                definition: defItem.asGenDef,
                topics: buildTopics(item: defItem)))
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        pages.append(GenData.Page(groupURL: groupItem.url,
                                  title: groupItem.title,
                                  breadcrumbs: buildBreadcrumbs(item: groupItem, parents: parents),
                                  content: nil,
                                  topics: buildTopics(item: groupItem)))
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: guideItem.url,
                                  title: guideItem.title,
                                  breadcrumbs: buildBreadcrumbs(item: guideItem, parents: parents),
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

    /// Breadcrumbs for a page
    /// Don't include the root: that's the readme/index.html handled separately.
    /// Include ourselves but without a URL.
    func buildBreadcrumbs(item: Item, parents: [Item]) -> [[GenData.Breadcrumb]] {
        languages.map {
            buildBreadcrumbs(for: $0, item: item, parents: parents)
        }
    }

    func buildBreadcrumbs(for language: DefLanguage, item: Item, parents: [Item]) -> [GenData.Breadcrumb] {
        var crumbs = parents.map {
            GenData.Breadcrumb(title: $0.titlePreferring(language: language), url: $0.url)
        }
        crumbs.append(GenData.Breadcrumb(title: item.titlePreferring(language: language), url: nil))
        return crumbs
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

extension Item {
    func title(for language: DefLanguage) -> Localized<String>? {
        switch language {
        case .swift: return swiftTitle
        case .objc: return objCTitle
        }
    }

    func titlePreferring(language: DefLanguage) -> Localized<String> {
        title(for: language) ?? title(for: language.otherLanguage)!
    }
}

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

    var primaryTitle: Localized<String> {
        title(for: primaryLanguage)!
    }

    var secondaryTitle: Localized<String>? {
        secondaryLanguage.flatMap { title(for: $0) }
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
