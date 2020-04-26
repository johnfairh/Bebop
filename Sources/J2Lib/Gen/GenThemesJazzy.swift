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
/// #piaf
extension Theme {

    // MARK: Global

    func jazzyGlobalData(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["jazzy_version"] = data[.j2libVersion]
        dict["language_stub"] = "cpp"
        dict["enable_katex"] = data[.enableKatex]
        dict["custom_head"] = data[.customHead]
        dict["disable_search"] = data[.hideSearch]
        dict["doc_coverage"] = data[.docCoverage]
        // jazzy sets "author_name" but it's not used.  Skip it.
        dict["dash_url"] = data[.docsetURL]

        defaultLanguage = (data[.defaultLanguage] as? String) ?? DefLanguage.swift.cssName
        return dict
    }

    // MARK: Nav

    /// Table of contents / left nav
    /// Jazzy themes support only two levels (until I sort out & merge that 2018 PR anyway) and
    /// a pseudo-third level formed by the third real level but with a spacer prefix on the second level!
    /// What a completely unnecessary nightmare.
    ///
    /// Always need a full URL even if the link is to something on the same page.
    private func buildJazzyDocStructure(from tocBlob: Any?) -> [MustacheDict]? {
        guard let tocDicts = tocBlob as? [MustacheDict],
            let tocDict = tocDicts.first(where: { $0[.language] as? String == defaultLanguage }),
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

    func jazzyDocStructure(from tocBlob: Any?) -> [MustacheDict]? {
        if jazzyDocStructureCache == nil {
            jazzyDocStructureCache = buildJazzyDocStructure(from: tocBlob)
        }
        return jazzyDocStructureCache
    }

    func jazzyPageData(from data: MustacheDict) -> MustacheDict {
        var dict = MustacheDict()
        dict["copyright"] = data[.copyrightHtml]
        dict["docs_title"] = data[.docsTitle]
        dict["path_to_root"] = data[.pathToAssets]
        dict["module_name"] = data[.breadcrumbsRoot] // approximately
        if data[.codehostGitHub] != nil {
            dict["github_url"] = data[.codehostURL]
        }
        dict["structure"] = jazzyDocStructure(from: data[.tocs])

        // split path for guide/not
        if data[.hideArticleTitle] != nil {
            if let title = data[.primaryPageTitle] as? String,
                title == "index",
                let moduleName = data[.breadcrumbsRoot] {
                dict["name"] = moduleName
            } else {
                dict["name"] = data[.primaryPageTitle]
            }
            // doc[:overview] = render(doc_model, doc_model.content(source_module))
            dict["hide_name"] = true
        } else {
            dict["name"] = data[.primaryTitle]
//            doc[:kind] = doc_model.type.name
//            doc[:dash_type] = doc_model.type.dash_type
//            doc[:declaration] = doc_model.display_declaration
//            doc[:overview] = overview
//            doc[:tasks] = render_tasks(source_module, doc_model.children)
//            doc[:deprecation_message] = doc_model.deprecation_message
//            doc[:unavailable_message] = doc_model.unavailable_message
//            doc[:usage_discouraged] = doc_model.usage_discouraged?
        }
        return dict
    }
}

private extension MustacheDict {
    func asJazzyTocBaseDict(name: String, prefix: String = "") -> MustacheDict {
        [name : prefix + (self[.title] as? String ?? ""),
         "url" : self[.fullURL] ?? self[.url] ?? ""]
    }
}

