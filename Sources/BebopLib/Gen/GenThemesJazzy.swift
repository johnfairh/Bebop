//
//  GenThemesJazzy.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// Compatibility mode for jazzy themes - get at least 95% of the way to rendering into an existing
/// jazzy theme.  Design choice was to completely redo the mustache data design for the 'real' theme
/// without regard to what jazzy did, and then here just map through brute force to the jazzy structure.
///
/// Main breakages are:
/// 1) Item-linking.  Jazzy inserts a leading "/" into anchors *in the mustache template* and this messes
///   up auto-linking and toc links and any kind of ref we generated in code.
///
/// Yay, yet more untyped dictionary spelunking.
///
/// #piaf
final class JazzyTheme: Theme {
    private var defaultLanguage: DefLanguage = .swift
    private var userCustomHead = ""

    // MARK: Global

    /// Slide in support for our style of syntax highlighting.
    /// Mustache doesn't do recursive template evaluation so we
    /// have to customize this per-page to get the href right.
    func customHead(pathToRoot: String) -> String {
        userCustomHead +
        """
        <link rel="stylesheet" href="\(pathToRoot)css/patch.min.css">
        <script src="\(pathToRoot)js/patch.min.js" defer></script>
        """
    }

    func convertGlobalData(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["jazzy_version"] = "Bebop " + (data[.bebopLibVersion] as? String ?? "")
        dict["language_stub"] = "cpp"
        dict["enable_katex"] = data[.enableKatex]
        dict["disable_search"] = data[.hideSearch]
        dict["doc_coverage"] = data[.docCoverage]
        // jazzy sets "author_name" but it's not used.  Skip it.
        dict["dash_url"] = data[.docsetURL]
        userCustomHead = (data[.customHead] as? String ?? "")
        return dict
    }

    // MARK: Nav

    /// Table of contents / left nav
    /// Jazzy themes support only two levels (until I sort out & merge that 2018 PR anyway) and
    /// a pseudo-third level formed by the third real level but with a spacer prefix on the second level!
    /// What a completely unnecessary nightmare.
    ///
    /// Always need a full URL even if the link is to something on the same page.
    private func buildDocStructure(from tocBlob: Any?) -> [MustacheDict]? {
        guard let tocDicts = tocBlob as? [MustacheDict],
            let tocDict = tocDicts.first(where: { $0[.language] as? String == defaultLanguage.cssName }),
            let toc = tocDict[.toc] as? [MustacheDict] else {
            return nil
        }
        return toc.map { data in
            var dict = data.asJazzyTocBaseDict(name: "section")
            if let childrenData = data[.children] as? [MustacheDict] {
                dict["children"] = childrenData.flatMap { childData -> [MustacheDict] in
                    let childDict = childData.asJazzyTocBaseDict(name: "name")
                    guard let grandChildrenData = childData[.children] as? [MustacheDict] else {
                        return [childDict]
                    }
                    return [childDict] + grandChildrenData.map {
                        $0.asJazzyTocBaseDict(name: "name", prefix: "- ")
                    }
                }
            }
            return dict
        }
    }

    // Jazzy's simpler view of the doc structure doesn't change across
    // pages so we can cache it.

    private var docStructureCache: [MustacheDict]?

    func docStructure(from tocBlob: Any?) -> [MustacheDict]? {
        if docStructureCache == nil {
            docStructureCache = buildDocStructure(from: tocBlob)
        }
        return docStructureCache
    }

    // MARK: Page

    func convertPageData(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["copyright"] = data[.copyrightHtml]
        dict["docs_title"] = data[.docsTitle]
        if let pathToRoot = data[.pathToAssets] as? String {
            dict["path_to_root"] = pathToRoot
            dict["custom_head"] = customHead(pathToRoot: pathToRoot)
        }
        dict["module_name"] = data[.breadcrumbsRoot] // approximately
        dict["github_url"] = data[.codehostURL] // approximately
        dict["structure"] = docStructure(from: data[.tocs])

        // split path for guide/not
        if let isGuide = data[.hideArticleTitle] as? Bool, isGuide {
            if let title = data[.primaryPageTitle] as? String,
                title == ReadmeItem.index,
                let moduleName = data[.breadcrumbsRoot] {
                dict["name"] = moduleName
            } else {
                dict["name"] = data[.primaryPageTitle]
            }
            dict["overview"] = data[.contentHtml]
            dict["hide_name"] = true
        } else {
            dict["name"] = data[.primaryPageTitle]
            if let defData = data[.def] as? MustacheDict {
                dict["overview"] =
                    (defData[.abstractHtml] as? String ?? "") +
                    (defData[.discussionHtml] as? String ?? "")
                let langMap = defData.asLangDeclarationMap
                dict["declaration"] =
                    langMap.jazzyHtmlFor(defaultLanguage) ?? langMap.jazzyHtmlFor(defaultLanguage.otherLanguage)
                dict["usage_discouraged"] = defData[.discouraged]
                dict["deprecation_message"] = defData[.deprecationHtml]
                dict["unavailable_message"] = defData[.unavailableHtml]
            }

            // omit kind at the page level, don't have it and doesn't add much
            // omit dash_type at the page level, doesn't make sense
            if let topicsData = data[.topics] as? [MustacheDict] {
                dict["tasks"] = topicsData.map { convertTask(from: $0) }
            }
        }
        return dict
    }

    func convertTask(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["name"] = (data[.dashName] as? String)?.removingPercentEncoding
        dict["name_html"] = data[.titleHtml]
        dict["uid"] = data[.anchorId]
        if let itemsData = data[.items] as? [MustacheDict] {
            dict["items"] = itemsData.map { convertItem(from: $0) }
        }
        return dict
    }

    func convertItem(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["name"] = data[.title]
        dict["name_html"] = data[.primaryTitleHtml]
        dict["usr"] = data[.anchorId]
        dict["dash_type"] = data[.dashType]
        dict["direct_link"] = !(data[.anyDeclaration] as? Bool ?? true)
        dict["url"] = data[.primaryUrl]
        guard let defData = data[.def] as? MustacheDict else {
            return dict
        }
        dict["abstract"] =
            (defData[.abstractHtml] as? String ?? "") +
            (defData[.discussionHtml] as? String ?? "")

        dict["usage_discouraged"] = defData[.discouraged]
        dict["deprecation_message"] = defData[.deprecationHtml]
        dict["unavailable_message"] = defData[.unavailableHtml]

        let defaultImpl =
            (defData[.defaultAbstractHtml] as? String ?? "") +
            (defData[.defaultDiscussionHtml] as? String ?? "")
        if !defaultImpl.isEmpty {
            dict["default_impl_abstract"] = defaultImpl
        }

        // from_protocol_extension: can't do, buried in declnotes
        // start_line: can't do, don't have, not used.
        // end_line: ditto

        dict["github_token_url"] = defData[.codehostURL]

        // Jazzy expresses the multi-lingual declarations in a super-weird
        // way.  It can't do 'first=objc second=swift'.
        let langMap = defData.asLangDeclarationMap
        for lang in [defaultLanguage, defaultLanguage.otherLanguage] {
            if let langDecl = langMap.jazzyHtmlFor(lang) {
                dict["declaration"] = langDecl
                dict["language"] = lang.humanName
                if lang == .objc, let swiftDecl = langMap.jazzyHtmlFor(.swift) {
                    dict["other_language_declaration"] = swiftDecl
                }
                break
            }
        }

        dict["return"] = defData[.returnsHtml]

        if let paramsData = defData[.parameters] as? [MustacheDict] {
            dict["parameters"] = paramsData.map {
                ["name": $0[.title], "discussion": $0[.parameterHtml]]
            }
        }

        return dict
    }

    // MARK: Overrides

    override func setGlobalData(_ data: MustacheDict) {
        super.setGlobalData(convertGlobalData(from: data))
    }

    override func setDefaultLanguage(_ language: DefLanguage) {
        defaultLanguage = language
    }

    override func renderTemplate(data: MustacheDict, languageTag: String) throws -> Html {
        try super.renderTemplate(data: convertPageData(from: data), languageTag: languageTag)
    }

    override var extensions: [GenThemes.Extension] {
        [.jazzy_patch] // prism syntax highlighting support
    }

    override func copyAssets(to docsSiteURL: URL) throws {
        try super.copyAssets(to: docsSiteURL)

        // Jazzy sass algorithm: take every "*.css.scss" file and convert it.
        let cssDirURL = docsSiteURL.appendingPathComponent("css")
        try cssDirURL.filesMatching("*.scss").forEach { scssURL in
            logDebug("Running sass over \(scssURL.path)")
            try Sass.renderInPlace(scssFileURL: scssURL)
            try FileManager.default.removeItem(at: scssURL)
        }
    }
}

// MARK: Helpers

/// Helper for decoding left-nav entries
private extension MustacheDict {
    func asJazzyTocBaseDict(name: String, prefix: String = "") -> MustacheDict {
        [name : prefix + (self[.title] as? String ?? ""),
         "url" : self[.fullURL] ?? self[.url] ?? ""]
    }
}

/// Helpers for mapping declaration formats/languages

private typealias DefLanguageDeclMap = [DefLanguage : String]

private extension MustacheDict {
    var asLangDeclarationMap: DefLanguageDeclMap {
        var dict = [DefLanguage : String]()
        if let swiftDecl = self[.swiftDeclarationHtml] as? String {
            dict[.swift] = swiftDecl
        }
        if let objCDecl = self[.objCDeclarationHtml] as? String {
            dict[.objc] = objCDecl
        }
        return dict
    }
}

private extension DefLanguageDeclMap {
    func jazzyHtmlFor(_ language: DefLanguage) -> String? {
        guard let decl = self[language] else {
            return nil
        }
        return #"<pre><code class="language-\#(language.prismName)">"# + decl + "</code></pre>"
    }
}
