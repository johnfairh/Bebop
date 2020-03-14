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
    let defaultLanguageOpt = EnumOpt<DefLanguage>(l: "default-language")

    private let published: Config.Published

    public init(config: Config) {
        published = config.published
        config.register(self)
    }

    public func generatePages(items: [Item]) throws -> GenData {
        let languageVisitor = LanguageVisitor()
        languageVisitor.walk(items: items)
        let languages = languageVisitor.languages
        let defaultLanguage = pickDefaultLanguage(from: languages)

        let pageVisitor = PageVisitor(languages: languages, defaultLanguage: defaultLanguage)
        pageVisitor.walk(items: items)
        let meta = GenData.Meta(version: Version.j2libVersion,
                                languages: languages,
                                defaultLanguage: defaultLanguage)

        let tocs = languages.map {
            generateToc(items: items, language: $0)
        }

        return GenData(meta: meta, tocs: tocs, pages: pageVisitor.pages)
    }

    /// Decide what the default language is -- affects some primary/secondary choices
    func pickDefaultLanguage(from languages: [DefLanguage]) -> DefLanguage {
        let modulesDefault = published.defaultLanguage // set according to 1-module input swift/objc
        let fallback = languages.contains(modulesDefault) ? modulesDefault : languages.first ?? .swift

        guard let userDefault = defaultLanguageOpt.value else {
            logDebug("Gen: Default language option not set, using '\(fallback)'.")
            return fallback
        }

        if languages.contains(userDefault) {
            logDebug("Gen: Default language from user option '\(userDefault)'.")
            return userDefault
        }
        if fallback != userDefault {
            logWarning(.localized(.wrnBadUserLanguage, userDefault, fallback))
        }
        return fallback
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
    private var foundLanguages = Set<DefLanguage>()
    var languages: [DefLanguage] {
        foundLanguages.isEmpty ? [.swift] : Array(foundLanguages).sorted(by: <)
    }

    func visit(defItem: DefItem, parents: [Item]) {
        foundLanguages.insert(defItem.primaryLanguage)
        if let secondaryLanguage = defItem.secondaryLanguage {
            foundLanguages.insert(secondaryLanguage)
        }
    }
}

final class PageVisitor: ItemVisitorProtocol {
    let languages: [DefLanguage]
    let defaultLanguage: DefLanguage

    init(languages: [DefLanguage], defaultLanguage: DefLanguage) {
        self.languages = languages
        self.defaultLanguage = defaultLanguage
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
        let primaryTitle = groupItem.titlePreferring(language: defaultLanguage)
        let secondaryTitle = groupItem.titlePreferring(language: defaultLanguage.otherLanguage)
        pages.append(GenData.Page(groupURL: groupItem.url,
                                  primaryTitle: primaryTitle,
                                  primaryLanguage: defaultLanguage,
                                  secondaryTitle: primaryTitle == secondaryTitle ? nil : secondaryTitle,
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
        let itemVisitor = GenItemVisitor(defaultLanguage: defaultLanguage)
        var currentTopic: Topic? = nil

        let uniquer = StringUniquer()

        func endTopic() {
            if let currentTopic = currentTopic {
                let slugRoot = currentTopic.title.plainText.get(Localizations.shared.main.tag)
                topics.append(GenData.Topic(title: currentTopic.title,
                                            menuTitle: currentTopic.menuTitle,
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

    var primaryTitle: Localized<String> {
        title(for: primaryLanguage)!
    }

    var secondaryTitle: Localized<String>? {
        secondaryLanguage.flatMap { title(for: $0) }
    }
}

/// Visitor to construct an Item that can appear inside a topic on a page.
class GenItemVisitor: ItemVisitorProtocol {
    let defaultLanguage: DefLanguage
    var items: [GenData.Item]

    init(defaultLanguage: DefLanguage) {
        self.defaultLanguage = defaultLanguage
        self.items = []
    }

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
            title: item.titlePreferring(language: defaultLanguage),
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
                    unavailability: unavailableNotice?.html,
                    notes: declNotesNotice?.html,
                    availability: swiftDeclaration?.availability ?? [],
                    abstract: documentation.abstract?.html,
                    discussion: documentation.discussion?.html,
                    defaultAbstract: documentation.defaultAbstract?.html,
                    defaultDiscussion: documentation.defaultDiscussion?.html,
                    swiftDeclaration: swiftDeclaration.flatMap { $0.declaration.html },
                    objCDeclaration: objCDeclaration.flatMap { $0.declaration.html },
                    params: documentation.parameters.map { docParam in
                        GenData.Param(name: docParam.name, description: docParam.description.html)
                    },
                    returns: documentation.returns?.html)
    }
}
