//
//  MustacheGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Generator

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

public typealias MustacheDict = [String: Any]

/// The type fed to the mustache templates to generate a page
public struct MustachePage {
    public let languageTag: String
    public let filepath: String
    public let data: MustacheDict
}

// MARK: Mustache Keys

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
    case hideAvailability = "hide_availability"
    case hideActions = "hide_actions"
    case docCoverage = "doc_coverage"
    case customHead = "custom_head"
    case itemCollapseOpen = "item_collapse_open"
    case itemCollapseNever = "item_collapse_never"
    case itemNest = "item_nest"
    case dualLanguage = "dual_language"
    case defaultLanguage = "default_language"
    case codehostGitHub = "codehost_github"
    case codehostGitLab = "codehost_gitlab"
    case codehostBitBucket = "codehost_bitbucket"
    case codehostCustom = "codehost_custom"
    case docsetURL = "docset_url"

    // Global, per-page
    case languageTag = "language_tag"
    case primaryPageTitle = "primary_page_title"
    case primaryTitleLanguage = "primary_title_language"
    case secondaryPageTitle = "secondary_page_title"
    case secondaryTitleLanguage = "secondary_title_language"
    case tabTitlePrefix = "tab_title_prefix"
    case pathToRoot = "path_to_root" // empty string or ends in "/"
    case tocs = "tocs"
    case toc = "toc"
    case hideArticleTitle = "hide_article_title"
    case contentHtml = "content_html"
    case apology = "apology"
    case noApologyLanguage = "no_apology_language"
    // Brand
    case brandImagePath = "brand_image_path"
    case brandAltText = "brand_alt_text"
    case brandTitle = "brand_title"
    case brandURL = "brand_url"
    // Codehost
    case codehostURL = "codehost_url"
    case codehostImagePath = "codehost_image_path"
    case codehostAltText = "codehost_alt_text"
    case codehostTitle = "codehost_title"
    case codehostDefLink = "codehost_def_link"
    // Global, set by SiteGen
    case pathToAssets = "path_to_assets" // empty string or ends in "/"
    case pathFromRoot = "path_from_root"
    case docsTitle = "docs_title"
    case breadcrumbsRoot = "breadcrumbs_root"
    case copyrightHtml = "copyright_html"
    // Localizations menu -- only set if there are multiple localizations
    case pageLocalization = "page_localization"
    case localizations = "localizations"
    case active = "active"
    case tag = "tag"
    case tagPath = "tag_path"
    // Breadcrumbs
    case breadcrumbsMenus = "breadcrumbs_menus"
    case breadcrumbs = "breadcrumbs"
    // Pagination
    case pagination = "pagination"
    case prev = "prev"
    case next = "next"

    // Definitions
    case def = "def"
    case deprecationHtml = "deprecation_html"
    case unavailableHtml = "unavailable_html"
    case notesHtml = "notes_html"
    case discouraged = "discouraged"
    case availability = "availability"
    case abstractHtml = "abstract_html"
    case discussionHtml = "discussion_html"
    case defaultAbstractHtml = "default_abstract_html"
    case defaultDiscussionHtml = "default_discussion_html"
    case swiftDeclarationHtml = "swift_declaration_html"
    case objCDeclarationHtml = "objc_declaration_html"
    case parameters = "parameters"
    case parameterHtml = "parameter_html"
    case returnsHtml = "returns_html"

    // Topics
    case topics = "topics"
    case topicsLanguage = "topics_language"
    case titleHtml = "title_html"
    case overviewHtml = "overview_html"
    case anchorId = "anchor_id"
    case dashName = "dash_name"

    // Topics menu
    case topicsMenus = "topics_menus"
    case topicsMenu = "topics_menu"
    case language = "language"

    // Items
    case items = "items"
    case dashType = "dash_type"
    case primaryTitle = "primary_title"
    case secondaryTitle = "secondary_title"
    case primaryTitleHtml = "primary_title_html"
    case secondaryTitleHtml = "secondary_title_html"
    case primaryLanguage = "primary_language"
    case secondaryLanguage = "secondary_language"
    case extensionConstraint = "extension_constraint"
    case anyDeclaration = "any_declaration"
    case primaryUrl = "primary_url"
    case secondaryUrl = "secondary_url"

    // ToC entries
    case title = "title"
    case url = "url"
    case samePage = "same_page"
    case children = "children"
    case screenReaderName = "screen_reader_name"

    static func dict(_ pairs: KeyValuePairs<MustacheKey, Any>) -> MustacheDict {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.rawValue, $0.1) })
    }
}

private func MH(_ pairs: KeyValuePairs<MustacheKey, Any>) -> MustacheDict {
    MustacheKey.dict(pairs)
}

extension Dictionary where Key == String, Value == Any {
    mutating func maybe(_ k: MustacheKey, _ v: Any?) {
        if let v = v {
            self[k.rawValue] = v
        }
    }
}

// MARK: Page

extension GenData {
    func generate(page: Int, languageTag: String, fileExt: String) -> MustachePage {
        var data = MustacheDict()
        let pg = pages[page]
        let filepath = pg.url.filepath(fileExtension: fileExt)
        data[.languageTag] = languageTag
        data[.primaryPageTitle] = pg.primaryTitle[languageTag]
        data[.primaryTitleLanguage] = pg.primaryLanguage.cssName
        if let secondaryTitle = pg.secondaryTitle {
            data[.secondaryPageTitle] = secondaryTitle[languageTag]
            data[.secondaryTitleLanguage] = pg.primaryLanguage.otherLanguage.cssName
        }
        data[.tabTitlePrefix] = pg.tabTitlePrefix
        data[.pathToRoot] = pg.url.pathToRoot
        data[.hideArticleTitle] = pg.isGuide
        data.maybe(.contentHtml, pg.content?.get(languageTag).html)
        data.maybe(.def, pg.def?.generateDef(languageTag: languageTag, fileExt: fileExt))

        data[.breadcrumbsMenus] = generateBreadcrumbs(for: pg, languageTag: languageTag, fileExt: fileExt)

        data[.topics] = pg.generateTopics(languageTag: languageTag, fileExt: fileExt)
        data.maybe(.topicsLanguage, pg.soloTopicsLanguage?.cssName)
        data[.topicsMenus] = generateTopicsMenus(page: pg, languageTag: languageTag)
        if meta.languages.count == 2 {
            data.maybe(.apology, pg.generateApology(languageTag: languageTag))
        }

        data[.tocs] = generateTocs(page: pg, languageTag: languageTag, fileExt: fileExt)
        data[.pagination] = pg.generatePagination(languageTag: languageTag, fileExt: fileExt)
        data.maybe(.codehostURL, pg.codeHostURL?.get(languageTag))

        return MustachePage(languageTag: languageTag, filepath: filepath, data: data)
    }

    /// Breadcrumbs root is array of breadcrumbs containers
    func generateBreadcrumbs(for page: Page, languageTag: String, fileExt: String) -> [MustacheDict] {
        zip(meta.languages, page.breadcrumbs).map {
            $0.1.generateBreadcrumbs(language: $0.0, languageTag: languageTag, fileExt: fileExt)
        }
    }

    /// Topics menus root is array of topics menu containers
    func generateTopicsMenus(page: Page, languageTag: String) -> [MustacheDict] {
        meta.languages.compactMap { lang in
            page.generateTopicsMenu(language: lang, languageTag: languageTag)
        }
    }

    /// Table-of-contents (left nav) root is array of toc containers
    /// This is unique for each page because the URLs change around the current page, and translation.
    func generateTocs(page: Page, languageTag: String, fileExt: String) -> [MustacheDict] {
        zip(meta.languages, tocs).map {
            $0.1.generateToc(page: page, language: $0.0, languageTag: languageTag, fileExt: fileExt)
        }
    }
}

// MARK: Apology

extension DefLanguage {
    var apologyMessage: Localized<String> {
        switch self {
        case .swift: return .localizedOutput(.notSwift)
        case .objc: return .localizedOutput(.notObjc)
        }
    }
}

extension GenData.Page {
    /// Apology - message for when the page doesn't make sense
    /// keys
    ///     title: text to display
    ///     language: language mode we should be in to display apology
    ///     no_apology_language: other mode (no apology)
    func generateApology(languageTag: String) -> MustacheDict? {
        func soloLanguage() -> DefLanguage? {
            if let def = def {
                return def.soloLanguage
            }
            return soloTopicsLanguage
        }

        guard !isGuide, let soloLanguage = soloLanguage() else {
            return nil
        }
        let apologyLanguage = soloLanguage.otherLanguage
        return MH([.title: apologyLanguage.apologyMessage.get(languageTag),
                   .language: apologyLanguage.cssName,
                   .noApologyLanguage: soloLanguage.cssName])
    }
}

// MARK: Table of Contents

extension Array where Element == GenData.TocEntry {
    /// A entire ToC for one language
    /// keys:
    ///     toc: the top-level array of toc entries
    ///     language: the css name for the toc's language
    ///     screen_reader_name: describe the `nav` element for accessibility
    func generateToc(page: GenData.Page, language: DefLanguage, languageTag: String, fileExt: String) -> MustacheDict {
        MH([.toc: generateTocEntries(pageURLPath: page.url.url(fileExtension: fileExt),
                                     tocActiveURLPath: page.tocActiveURL?.url(fileExtension: fileExt),
                                     language: language,
                                     languageTag: languageTag,
                                     fileExt: fileExt),
            .language: language.cssName,
            .screenReaderName: language.humanName])
    }

    /// Helper to generate a list of toc entries
    func generateTocEntries(pageURLPath: String, tocActiveURLPath: String?, language: DefLanguage, languageTag: String, fileExt: String) -> [MustacheDict] {
        map { $0.generateTocEntry(pageURLPath: pageURLPath,
                                  tocActiveURLPath: tocActiveURLPath,
                                  language: language,
                                  languageTag: languageTag,
                                  fileExt: fileExt) }
    }
}

extension GenData.TocEntry {
    /// One entry in the table of contents
    /// keys:
    ///   title: text for the entry
    ///   children: option array of this same format
    ///   url: optional href to the entry [not set if we're already there]
    ///   same_page: true if 'url' is a #href on the same page we're on
    ///   active: true if this should be marked active *even though* it's for a different page
    func generateTocEntry(pageURLPath: String, tocActiveURLPath: String?, language: DefLanguage, languageTag: String, fileExt: String) -> MustacheDict {
        let entryURLPath = url.url(fileExtension: fileExt, language: language)
        var dict = MH([.title: title.get(languageTag)])
        let entries = children.generateTocEntries(pageURLPath: pageURLPath,
                                                  tocActiveURLPath: tocActiveURLPath,
                                                  language: language,
                                                  languageTag: languageTag,
                                                  fileExt: fileExt)
        if !entries.isEmpty {
            dict[.children] = entries
        }
        if entryURLPath.hasPrefix(pageURLPath) {
            // #link to something on the same page
            dict[.url] = url.hashURL
            dict[.samePage] = true
        } else {
            dict[.url] = entryURLPath
            dict[.samePage] = false
            if let tocActiveURLPath = tocActiveURLPath, entryURLPath.hasPrefix(tocActiveURLPath) {
                dict[.active] = true
            }
        }
        return dict
    }
}

// MARK: Breadcrumbs

extension Array where Element == GenData.Breadcrumb {
    /// Breadcrumbs keys:
    ///       breadcrumbs: array of breadcrumbs
    ///       language: css class for language mode
    func generateBreadcrumbs(language: DefLanguage, languageTag: String, fileExt: String) -> MustacheDict {
        let crumbs = map { $0.generateBreadcrumb(language: language, languageTag: languageTag, fileExt: fileExt)}
        return MH([.breadcrumbs: crumbs, .language: language.cssName])
    }
}

extension GenData.Breadcrumb {
    /// Breadcrumb keys:
    ///     title: text to display for breadcrumb
    ///     url: full url for breadcrumb, optional (not set for self)
    func generateBreadcrumb(language: DefLanguage, languageTag: String, fileExt: String) -> MustacheDict {
        var dict = MH([.title: title.get(languageTag)])
        dict.maybe(.url, url?.url(fileExtension: fileExt, language: language))
        return dict
    }
}

// MARK: Pagination

extension GenData.Page {
    func generatePagination(languageTag: String, fileExt: String) -> MustacheDict {
        var dict = MustacheDict()
        dict.maybe(.prev, pagination.prev?.generatePaginationLink(languageTag: languageTag, fileExt: fileExt))
        dict.maybe(.next, pagination.next?.generatePaginationLink(languageTag: languageTag, fileExt: fileExt))
        return dict
    }
}

extension GenData.PaginationLink {
    func generatePaginationLink(languageTag: String, fileExt: String) -> MustacheDict {
        MH([.primaryLanguage: primaryLanguage.cssName,
            .primaryUrl: url.url(fileExtension: fileExt, language: primaryLanguage),
            .primaryTitle: primaryTitle.get(languageTag),
            .secondaryLanguage: primaryLanguage.otherLanguage.cssName,
            .secondaryUrl: url.url(fileExtension: fileExt, language: primaryLanguage.otherLanguage),
            .secondaryTitle: secondaryTitle.get(languageTag)
        ])
    }
}

// MARK: Topics

extension GenData.Page {
    /// topics is an array of [String : Any]
    func generateTopics(languageTag: String, fileExt: String) -> [MustacheDict] {
        topics.map { $0.generateTopic(languageTag: languageTag, fileExt: fileExt) }
    }

    /// topics_menu is array of [String:Any]
    /// keys:  title - plain text title of topic
    ///      anchor_id - href without leading hash of topic on page
    ///
    /// There's one topics menu for each language on the page.
    /// Include a 'Declaration' item for the main item if present.
    func generateTopicsMenuItems(language: DefLanguage,
                                 languageTag: String) -> [MustacheDict] {
        var topicsMenu = [MustacheDict]()
        if def != nil {
            let declarationLabel = Localized<String>.localizedOutput(.declaration)
            let declaration = declarationLabel.get(languageTag)
            topicsMenu.append(MH([.title: declaration, .anchorId: ""]))
        }
        return topicsMenu +
            topics.compactMap { $0.generateMenuItem(language: language, languageTag: languageTag) }
    }

    /// Get the menu for a particular language, can be absent entirely
    /// keys:  topics_menu - array of menu items
    ///      language - language for menu
    func generateTopicsMenu(language: DefLanguage, languageTag: String) -> MustacheDict? {
        let menuItems = generateTopicsMenuItems(language: language, languageTag: languageTag)
        guard !menuItems.isEmpty else {
            return nil
        }
        return MH([.topicsMenu: menuItems, .language: language.cssName])
    }

    /// Identify if all topics are dependent on one language
    var soloTopicsLanguage: DefLanguage? {
        topics.soloLanguage
    }
}

// Helpers to deal with cascading 'only visible in one language' up the tree
// of item -> topic -> topics.

protocol SoloLanguageProtocol {
    /// Is the thing present in just one language, if so which one?
    var soloLanguage: DefLanguage? { get }
}

extension Array: SoloLanguageProtocol where Element: SoloLanguageProtocol {
    var soloLanguage: DefLanguage? {
        var theLanguage: DefLanguage? = nil
        for item in self {
            guard let itemSoloLanguage = item.soloLanguage else {
                // dual language
                return nil
            }
            if theLanguage == nil {
                theLanguage = itemSoloLanguage // first match
            } else if theLanguage != itemSoloLanguage {
                return nil // different 1-language
            }
        }
        return theLanguage
    }
}

extension GenData.Topic: SoloLanguageProtocol {
    var soloLanguage: DefLanguage? {
        items.soloLanguage
    }

    /// topics is an array of [String : Any]
    /// with keys title_html [can be missing if 0 title]
    ///           overview_html [can be missing]
    ///           anchor_id -- need for linking from aux nav
    ///           dash_name - %-encoded text (markdown) name
    ///           primary_language - if set then topic is only valid in that language
    ///           items - items array of [String: Any]
    func generateTopic(languageTag: String, fileExt: String) -> MustacheDict {
        let titleText = menuTitle.get(languageTag)
        let dashName = titleText.urlPathEncoded
        var dict = MH([.anchorId: anchorId, .dashName: dashName])
        if !titleText.isEmpty {
            dict[.titleHtml] = title.get(languageTag).html
        }
        dict.maybe(.overviewHtml, overview?.get(languageTag).html)
        dict.maybe(.primaryLanguage, soloLanguage?.cssName)
        if items.count > 0 {
            dict[.items] = items.map {
                $0.generateItem(languageTag: languageTag, fileExt: fileExt)
            }
        }
        return dict
    }

    /// Build the topics menu item - nil if no title or only in the other language
    func generateMenuItem(language: DefLanguage, languageTag: String) -> MustacheDict? {
        let titleText = menuTitle.get(languageTag)
        if titleText.isEmpty {
            return nil
        }
        if let soloLanguage = soloLanguage,
            soloLanguage == language.otherLanguage {
            return nil
        }

        return MH([.title: titleText,
                   .anchorId: anchorId.urlFragmentEncoded])
    }
}

// MARK: Item

extension GenData.Item: SoloLanguageProtocol {
    /// Item has keys
    ///     anchor_id
    ///     title -- text title for meta refs & direct-links
    ///     prim|sec_title_html -- language defs, prim/sec is about which to show in dash (etc) mode
    ///     extension_constraint -- optional text to follow title
    ///     prim|sec_language -- css-appendable class tag for other prim-sec stuff
    ///     any_declaration -- F means direct_link
    ///     dash_type -- for dash links
    ///     dash_name -- title, %-encoded
    ///     primaryUrl -- optional, link for more in primary language
    ///     secondaryUrl -- optional, link for more in secondary language
    ///     def -- optional, popopen item definition
    func generateItem(languageTag: String, fileExt: String) -> MustacheDict {
        let title = flatTitle.get(languageTag)
        var hash = MH([.anchorId: anchorId,
                       .title: title,
                       .dashName: title.urlPathEncoded,
                       .anyDeclaration: primaryTitleHtml != nil || secondaryTitleHtml != nil,
                       .primaryLanguage: primaryLanguage.cssName])

        hash.maybe(.primaryTitleHtml, primaryTitleHtml?.html)
        hash.maybe(.secondaryLanguage, secondaryLanguage?.cssName)
        hash.maybe(.secondaryTitleHtml, secondaryTitleHtml?.html)
        hash.maybe(.extensionConstraint, extensionConstraint?.get(languageTag))
        hash.maybe(.dashType, dashType)
        hash.maybe(.primaryUrl, url?.url(fileExtension: fileExt, language: primaryLanguage))
        hash.maybe(.secondaryUrl, secondaryLanguage.flatMap { url?.url(fileExtension: fileExt, language: $0) })
        hash.maybe(.def, def?.generateDef(languageTag: languageTag, fileExt: fileExt))

        return hash
    }

    /// Is the item present in just one language?
    var soloLanguage: DefLanguage? {
        def.flatMap { $0.soloLanguage }
    }
}

// MARK: Def

extension GenData.Def: SoloLanguageProtocol {
    /// Def is split out because shared between top of page and inside items.
    /// Keys:
    ///   deprecation_html  - optional - is it deprecated
    ///   unavailable_html  - optional - is it unavailable
    ///   notes_html - optional - are there interesting notes
    ///   discouraged - optional - is it deprecated/unavailable
    ///   swift_declaration_html - swift decl
    ///   objc_declaration_html - objc decl --- at least one of these two will be set
    ///   abstract_html - optional - first part of discussion
    ///   discussion_html - optional - second part of discussion
    ///   default_abstract_html - optional - first part of default implementation abstract
    ///   default_discussion_html - optional - rest of default implementation abstract
    ///   parameters - optional - array of title / parameter_html
    ///   returns_html - optional - returns docs
    func generateDef(languageTag: String, fileExt: String) -> MustacheDict {
        var dict = MustacheDict()
        dict.maybe(.deprecationHtml, deprecation?.get(languageTag).html)
        dict.maybe(.unavailableHtml, unavailability?.get(languageTag).html)
        dict.maybe(.notesHtml, notes?.get(languageTag).html)
        if deprecation != nil || unavailability != nil {
            dict[.discouraged] = true
        }
        if !availability.isEmpty {
            dict[.availability] = availability
        }
        dict.maybe(.swiftDeclarationHtml, swiftDeclaration?.html)
        dict.maybe(.objCDeclarationHtml, objCDeclaration?.html)
        dict.maybe(.abstractHtml, abstract?.get(languageTag).html)
        dict.maybe(.discussionHtml, discussion?.get(languageTag).html)
        dict.maybe(.defaultAbstractHtml, defaultAbstract?.get(languageTag).html)
        dict.maybe(.defaultDiscussionHtml, defaultDiscussion?.get(languageTag).html)
        if !params.isEmpty {
            dict[.parameters] = params.map {
                MH([.title: $0.name, .parameterHtml: $0.description.get(languageTag).html])
            }
        }
        dict.maybe(.returnsHtml, returns?.get(languageTag).html)
        dict.maybe(.codehostURL, codeHostURL)
        return dict
    }

    var soloLanguage: DefLanguage? {
        if swiftDeclaration == nil {
            return .objc
        } else if objCDeclaration == nil {
            return .swift
        }
        return nil
    }
}
