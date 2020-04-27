//
//  GenThemesJazzy.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Compatibility mode for jazzy themes - get at least 95% of the way to rendering into an existing
/// jazzy theme.  Design choice was to completely redo the mustache data design for the 'real' theme
/// without regard to what jazzy did, and then here just map through brute force to the jazzy structure.
///
/// Yay, yet more untyped dictionary spelunking.
///
/// #piaf
final class JazzyTheme: Theme {
    private var defaultLanguage: DefLanguage = .swift

    // MARK: Global

    func convertGlobalData(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["jazzy_version"] = data[.j2libVersion]
        dict["language_stub"] = "cpp"
        dict["enable_katex"] = data[.enableKatex]
        dict["custom_head"] = data[.customHead]
        dict["disable_search"] = data[.hideSearch]
        dict["doc_coverage"] = data[.docCoverage]
        // jazzy sets "author_name" but it's not used.  Skip it.
        dict["dash_url"] = data[.docsetURL]
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
        dict["path_to_root"] = data[.pathToAssets]
        dict["module_name"] = data[.breadcrumbsRoot] // approximately
        dict["github_url"] = data[.codehostURL] // approximately
        dict["structure"] = docStructure(from: data[.tocs])

        // split path for guide/not
        if let isGuide = data[.hideArticleTitle] as? Bool, isGuide {
            if let title = data[.primaryPageTitle] as? String,
                title == "index",
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
//            doc[:tasks] = render_tasks(source_module, doc_model.children)
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

    override func renderTemplate(data: MustacheDict) throws -> Html {
        try super.renderTemplate(data: convertPageData(from: data))
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
