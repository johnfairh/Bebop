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

    private let published: Published

    public init(config: Config) {
        published = config.published
        config.register(self)
    }

    public func generatePages(items: [Item]) throws -> GenData {
        let languageVisitor = LanguageVisitor()
        try languageVisitor.walk(items: items)
        let languages = languageVisitor.languages
        let defaultLanguage = pickDefaultLanguage(from: languages)

        let pageVisitor = PageVisitor(languages: languages,
                                      defaultLanguage: defaultLanguage,
                                      published: published)
        try pageVisitor.walk(items: items)
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
            items.compactMap { item -> GenData.TocEntry? in
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
                var children = doGenerate(items: item.children, depth: depth + 1)

                // Jazzy holdover: if we're in source-order mode (jazzy mode) and
                // this isn't a custom group, then we have to sort the ToC even though
                // this pulls the order out of sync with the page.
                if published.sourceOrderDefs && !item.isCustomGroup {
                    children.sort { $0.title < $1.title }
                }

                return GenData.TocEntry(url: item.url,
                                        title: title,
                                        children: children)
            }
        }

        return doGenerate(items: items, depth: 0)
    }
}

extension Item {
    public var isCustomGroup: Bool {
        guard let groupItem = self as? GroupItem else { return false }
        return groupItem.groupKind.isCustom
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

private extension Html {
    func autolinked(_ pageURL: URLPieces) -> Html {
        FormatAutolink.fixUpAutolinks(html: self, pathToRoot: pageURL.pathToRoot)
    }
}

private extension Localized where Value == Html {
    func autolinked(_ pageURL: URLPieces) -> Self {
        mapValues { $0.autolinked(pageURL) }
    }
}

final class PageVisitor: ItemVisitorProtocol {
    let languages: [DefLanguage]
    let defaultLanguage: DefLanguage
    let published: Published

    init(languages: [DefLanguage], defaultLanguage: DefLanguage, published: Published) {
        self.languages = languages
        self.defaultLanguage = defaultLanguage
        self.published = published
    }

    /// All pages
    var pages = [GenData.Page]()

    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.renderAsPage {
            pages.append(GenData.Page(
                defURL: defItem.url,
                // This thing is about child-style=separate, where we have pages that do not
                // appear in the nav at all.  It looks weird, so we highlight the parent def.
                // So this is valid only in that case 'highlight this thing instead of trying to find me'.
                tocActiveURL: defItem.showInToc != .yes ? (defItem.parent as? DefItem)?.url : nil,
                primaryTitle: defItem.primaryTitle,
                primaryLanguage: defItem.primaryLanguage,
                secondaryTitle: defItem.secondaryTitle,
                breadcrumbs: buildBreadcrumbs(item: defItem, parents: parents),
                definition: defItem.asGenDef(pageURL: defItem.url, published: published),
                topics: buildTopics(item: defItem),
                pagination: buildPagination(item: defItem),
                codeHostURL: published.module(defItem.location.moduleName).codeHostURL))
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
                                  content: groupItem.customAbstract?.html.autolinked(groupItem.url),
                                  topics: buildTopics(item: groupItem),
                                  pagination: buildPagination(item: groupItem),
                                  codeHostURL: published.codeHostFallbackURL))
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: guideItem.url,
                                  title: guideItem.title,
                                  breadcrumbs: buildBreadcrumbs(item: guideItem, parents: parents),
                                  isReadme: false,
                                  content: guideItem.content.html.autolinked(guideItem.url),
                                  pagination: buildPagination(item: guideItem),
                                  codeHostURL: published.codeHostFallbackURL))
    }

    func visit(readmeItem: ReadmeItem, parents: [Item]) {
        pages.append(GenData.Page(guideURL: readmeItem.url,
                                  title: readmeItem.title,
                                  breadcrumbs: [],
                                  isReadme: true,
                                  content: readmeItem.content.html.autolinked(readmeItem.url),
                                  pagination: buildPagination(item: readmeItem),
                                  codeHostURL: published.codeHostFallbackURL))
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
        let allItems = parents + [item]
        var prevItemIsCode = false
        var needQualifiedName = true
        let titles = allItems.map { item -> Localized<String> in
            let itemIsCode = item is DefItem
            defer { prevItemIsCode = itemIsCode }

            if let groupItem = item as? GroupItem {
                needQualifiedName = published.isMultiModule && !groupItem.groupKind.includesModuleName
            }

            guard let defItem = item as? DefItem,
                !prevItemIsCode,
                needQualifiedName || defItem.defKind.isSwiftExtension else {
                return item.titlePreferring(language: language)
            }
            return defItem.extendedBreadcrumbTitle(language: language, qualified: needQualifiedName)
        }

        let crumbs = zip(titles, parents).map {
            GenData.Breadcrumb(title: $0, url: $1.url)
        }
        return crumbs + [GenData.Breadcrumb(title: titles.last!, url: nil)]
    }

    func buildTopics(item: Item) -> [GenData.Topic] {
        var topics = [GenData.Topic]()
        let itemVisitor = GenItemVisitor(defaultLanguage: defaultLanguage,
                                         pageURL: item.url,
                                         published: published)
        var currentTopic: Topic? = nil

        let uniquer = StringUniquer()

        func endTopic() {
            if let currentTopic = currentTopic {
                let slugRoot = currentTopic.title.plainText.get(Localizations.shared.main.tag)
                topics.append(GenData.Topic(title: currentTopic.title.html.autolinked(item.url),
                                            menuTitle: currentTopic.menuTitle.plainText,
                                            anchorId: uniquer.unique("tpc-" + slugRoot.slugged),
                                            overview: currentTopic.overview?.html.autolinked(item.url),
                                            items: itemVisitor.resetItems()))
            }
        }

        item.children.forEach { child in
            if child.topic !== currentTopic {
                endTopic()
                currentTopic = child.topic
            }
            try! itemVisitor.walkOne(item: child)
        }
        endTopic()
        return topics
    }

    /// Pagination links for a page
    func buildPagination(item: Item) -> GenData.Pagination {
        GenData.Pagination(prev: buildPaginationLink(to: item.linearPrev),
                           next: buildPaginationLink(to: item.linearNext))
    }

    func buildPaginationLink(to item: Item?) -> GenData.PaginationLink? {
        guard let item = item else {
            return nil
        }
        let primaryLanguage = (item as? DefItem).flatMap { $0.primaryLanguage } ?? defaultLanguage
        return GenData.PaginationLink(url: item.url,
                                      primaryTitle: item.titlePreferring(language: primaryLanguage),
                                      secondaryTitle: item.titlePreferring(language: primaryLanguage.otherLanguage),
                                      primaryLanguage: primaryLanguage)
    }
}

// MARK: Items

extension DefItem {
    var primaryTitle: Localized<String> {
        title(for: primaryLanguage)!
    }

    var secondaryTitle: Localized<String>? {
        secondaryLanguage.flatMap { title(for: $0) }
    }

    func extendedBreadcrumbTitle(language: DefLanguage, qualified: Bool) -> Localized<String> {
        let baseTitle = titlePreferring(language: language)
        let modTitle = baseTitle.mapValues { "\(typeModuleName).\($0)" }
        guard defKind.isSwiftExtension && qualified else {
            return modTitle
        }
        return modTitle + " (\(location.moduleName))"
    }

    /// Only print the '(where T: Codable)' thing if we are not inside a topic generated to express that.
    /// In practice this means when custom_defs has been used to rearrange things.
    var extensionConstraintMessage: Localized<String>? {
        guard let constraint = extensionConstraint,
            let topic = topic,
            topic.kind != .genericRequirements else {
                return nil
        }
        return constraint.richLong.plainText
    }
}

/// Visitor to construct an Item that can appear inside a topic on a page.
class GenItemVisitor: ItemVisitorProtocol {
    let defaultLanguage: DefLanguage
    let pageURL: URLPieces
    let published: Published

    var items: [GenData.Item]

    init(defaultLanguage: DefLanguage, pageURL: URLPieces, published: Published) {
        self.defaultLanguage = defaultLanguage
        self.pageURL = pageURL
        self.published = published
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
                Html($0.wrappingOther(before: #"<span class="j2-item-secondary">"#,
                                      after: "</span>",
                                      xform: { $0.htmlEscaped }))
            }
        }
        items.append(GenData.Item(
            anchorId: defItem.slug,
            flatTitle: .init(unlocalized: defItem.primaryNamePieces.flattened),
            primaryLanguage: defItem.primaryLanguage,
            secondaryLanguage: defItem.secondaryLanguage,
            primaryTitleHtml: titleHtmls[0],
            secondaryTitleHtml: titleHtmls[1],
            extensionConstraint: defItem.extensionConstraintMessage,
            dashType: defItem.defKind.dashName,
            url: defItem.renderAsPage ? defItem.url : nil,
            def: defItem.asGenDef(pageURL: pageURL, published: published)))
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
    func asGenDef(pageURL: URLPieces, published: Published) -> GenData.Def {
        GenData.Def(deprecation: deprecationNotice?.html.autolinked(pageURL),
                    unavailability: unavailableNotice?.html.autolinked(pageURL),
                    notes: declNotesNotice?.html.autolinked(pageURL),
                    availability: swiftDeclaration?.availability ?? [],
                    abstract: documentation.abstract?.html.autolinked(pageURL),
                    discussion: documentation.discussion?.html.autolinked(pageURL),
                    defaultAbstract: documentation.defaultAbstract?.html.autolinked(pageURL),
                    defaultDiscussion: documentation.defaultDiscussion?.html.autolinked(pageURL),
                    swiftDeclaration: swiftDeclaration.flatMap { $0.declaration.html.autolinked(pageURL) },
                    objCDeclaration: objCDeclaration.flatMap { $0.declaration.html.autolinked(pageURL) },
                    params: documentation.parameters.map { docParam in
                        GenData.Param(name: docParam.name,
                                      description: docParam.description.html.autolinked(pageURL))
                    },
                    returns: documentation.returns?.html.autolinked(pageURL),
                    codeHostURL: published.codeHostItemURLForLocation(location))
    }
}
