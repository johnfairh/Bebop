//
//  MustacheGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Gubbins to generate a sequence of `MustachePage`s from a `GenData`.
/// This loops over all the pages for every language being produced.
extension GenData {
    public struct Iterator: IteratorProtocol {
        let genData: GenData
        let fileExt: String
        var locIterator: Array<String>.Iterator
        var nextPage: Int
        var currentLanguageTag: String

        init(genData: GenData, fileExt: String) {
            self.genData = genData
            self.fileExt = fileExt
            self.locIterator = Localizations.shared.allTags.makeIterator()
            self.nextPage = 0
            self.currentLanguageTag = locIterator.next()!
        }

        public mutating func next() -> MustachePage? {
            if nextPage == genData.pages.count {
                // done all the pages of the current language
                guard let nextLanguageTag = locIterator.next() else {
                    // No more languages: the end
                    return nil
                }
                currentLanguageTag = nextLanguageTag
                nextPage = 0
            }
            defer { nextPage += 1 }
            return genData.generate(page: nextPage,
                                    languageTag: currentLanguageTag,
                                    fileExt: fileExt)
        }
    }

    public func makeIterator(fileExt: String) -> Iterator {
        Iterator(genData: self, fileExt: fileExt)
    }
}

// MARK: Generate

/// The type fed to the mustache templates to generate a page
public struct MustachePage {
    let languageTag: String
    let filepath: String
    let data: [String : Any]
}

extension Dictionary where Key == String {
    subscript(arg: MustacheKey) -> Value? {
        set { self[arg.rawValue] = newValue }
        get { self[arg.rawValue] }
    }
}

public enum MustacheKey: String {
    // Global, fixed
    case j2libVersion = "j2lib_version"
    case hideSearch = "disable_search"
    case hideAttribution = "hide_attribution"
    case docCoverage = "doc_coverage"
    case customHead = "custom_head"

    // Global, per-page
    case languageTag = "language_tag"
    case pageTitle = "page_title"
    case tabTitlePrefix = "tab_title_prefix"
    case pathToRoot = "path_to_root" // empty string or ends in "/"
    case toc = "toc"
    case hideArticleTitle = "hide_article_title"
    // Global, set by SiteGen
    case pathToAssets = "path_to_assets" // empty string or ends in "/"
    case docsTitle = "docs_title"
    case breadcrumbsRoot = "breadcrumbs_root"
    // Localizations menu -- only set if there are multiple localizations
    case pageLocalization = "page_localization"
    case localizations = "localizations"

    // Content
    case abstractHtml = "abstract_html"
    case overviewHtml = "overview_html"
    case anyDeclaration = "any_declaration"
    case swiftDeclarationHtml = "swift_declaration_html"

    // Topics
    case topics = "topics"
    case titleHtml = "title_html"
    case anchorId = "anchor_id"
    case dashName = "dash_name"

    // Topics menu
    case topicsMenu = "topics_menu"

    // ToC entries
    case title = "title"
    case url = "url"
    case active = "active"
    case children = "children"

    static func dict(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.rawValue, $0.1) })
    }
}

private func MH(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
    MustacheKey.dict(pairs)
}

extension GenData {
    public func generate(page: Int, languageTag: String, fileExt: String) -> MustachePage {
        var data = [String: Any]()
        let pg = pages[page]
        let filepath = pg.url.filepath(fileExtension: fileExt)
        data[.languageTag] = languageTag
        data[.pageTitle] = pg.title[languageTag]
        data[.tabTitlePrefix] = pg.tabTitlePrefix
        data[.pathToRoot] = pg.url.pathToRoot
        data[.hideArticleTitle] = pg.isGuide
        data[.abstractHtml] = pg.abstract?[languageTag]?.html
        data[.overviewHtml] = pg.overview?[languageTag]?.html
        data[.swiftDeclarationHtml] = pg.swiftDeclaration?.html
        let anyDeclaration = pg.swiftDeclaration != nil
        data[.anyDeclaration] = anyDeclaration

        let topics = pg.generateTopics(languageTag: languageTag)
        data[.topics] = topics
        data[.topicsMenu] = generateTopicsMenu(topics: topics,
                                               anyDeclaration: anyDeclaration,
                                               languageTag: languageTag)

        data[.toc] = generateToc(languageTag: languageTag,
                                 fileExt: fileExt,
                                 pageURLPath: pg.url.url(fileExtension: fileExt))



        return MustachePage(languageTag: languageTag, filepath: filepath, data: data)
    }

    /// TopicsMenu is array of [String : Any]
    ///    title -- text for link
    ///    anchor_id -- without #
    /// Add an item for the top declaration if there is one.
    func generateTopicsMenu(topics: [[String: Any]], anyDeclaration: Bool, languageTag: String) -> [[String: Any]] {
        var topicsMenu = [[String: Any]]()
        if anyDeclaration {
            let declaration = Localized<String>.localizedOutput(.declaration).get(languageTag)
            topicsMenu.append(MH([.title: declaration, .anchorId: ""]))
        }
        return topicsMenu +
            topics.compactMap { hash in
                guard let title = hash[.title] as? String,
                    let anchorId = hash[.anchorId] as? String else {
                        return nil
                }
                return MH([.title: title.re_sub("[_`*]+", with: ""),
                           .anchorId: "\(anchorId.urlFragmentEncoded)"])
            }
    }

    /// Generate the table of contents (left nav) for the page.
    /// This is unique for each page because the 'active' element changes and translation.
    func generateToc(languageTag: String, fileExt: String, pageURLPath: String) -> [[String : Any]] {

        func tocList(entries: [TocEntry]) -> [[String : Any]] {
            entries.map { entry in
                let entryURLPath = entry.url.url(fileExtension: fileExt)
                return MH([.title: entry.title.get(languageTag),
                           .url: entryURLPath,
                           .active: entryURLPath == pageURLPath,
                           .children: tocList(entries: entry.children)])
            }
        }

        return tocList(entries: toc)
    }
}

extension GenData.Page {
    /// topics is an array of [String : Any]
    /// with keys title_html [can be missing if 0 title]
    ///           overview_html [can be missing] [use . syntax!!]
    ///           anchorId -- need for linking from aux nav
    ///           dashName - %-encoded text (markdown) name
    ///
    /// items is itself an array of [String : Any]
    func generateTopics(languageTag: String) -> [[String : Any]] {
        return topics.map { topic in
            let title = topic.title.markdown.get(languageTag).md
            let dashName = title.urlPathEncoded
            var hash = MH([.anchorId: topic.anchorId, .dashName: dashName])
            if !title.isEmpty {
                hash[.title] = title
                hash[.titleHtml] = topic.title.html.get(languageTag).html
            }
            if let body = topic.body {
                hash[.overviewHtml] = body.get(languageTag).html
            }
            return hash
        }
    }
}
