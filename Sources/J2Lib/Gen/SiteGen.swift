//
//  Gen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `SiteGen` produces docs output data from an `Item` forest.
///
/// tbd whether we need the pagegen / sitegen split - just stubs really
public struct SiteGen: Configurable {
    let outputOpt = PathOpt(s: "o", l: "output").help("PATH").def("docs")
    let cleanOpt = BoolOpt(s: "c", l: "clean")

    let disableSearchOpt = BoolOpt(l: "disable-search")
    let hideAttributionOpt = BoolOpt(l: "hide-attribution")
    let hideCoverageOpt = BoolOpt(l: "hide-coverage")
    let customHeadOpt = StringOpt(l: "custom-head").help("HTML")

    let titleOpt = LocStringOpt(l: "title").help("TITLE")
    let moduleVersionOpt = StringOpt(l: "module-version").help("VERSION")
    let breadcrumbsRootOpt = LocStringOpt(l: "breadcrumbs-root").help("TITLE")

    let oldHideCoverageOpt: AliasOpt
    let oldCustomHeadOpt: AliasOpt

    var outputURL: URL {
        outputOpt.value!
    }

    let themes: Themes

    public init(config: Config) {
        themes = Themes(config: config)

        oldHideCoverageOpt = AliasOpt(realOpt: hideCoverageOpt, l: "hide-documentation-coverage")
        oldCustomHeadOpt = AliasOpt(realOpt: customHeadOpt, l: "head")

        config.register(self)
    }

    public func generate(genData: GenData) throws {
        let theme = try themes.select()

        logInfo(.localized(.msgGeneratingDocs))

        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            try FileManager.default.removeItem(at: outputURL)
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        theme.setGlobalData(globalData)

        let docsTitle = buildDocsTitle(genData: genData)
        let breadcrumbsRoot = buildBreadcrumbRoot(genData: genData)

        var pageIterator = genData.makeIterator(fileExt: theme.fileExtension)

        while let page = pageIterator.next() {
            let location = page.getLocation()

            var mustacheData = page.data
            mustacheData[.pathToAssets] = location.reversePath
            mustacheData[.docsTitle] = docsTitle.get(page.languageTag)
            mustacheData[.breadcrumbsRoot] = breadcrumbsRoot.get(page.languageTag)

            let locs = Localizations.shared

            if locs.all.count > 1 {
                mustacheData[.pageLocalization] =
                    locs.localization(languageTag: page.languageTag).flag
                mustacheData[.localizations] =
                    buildLocalizations(page: page,
                                       currentPathToAssets: location.reversePath)
            }

            logDebug("Gen: Rendering template for \(page.data[.pageTitle]!)")
            let rendered = try theme.renderTemplate(data: mustacheData)

            let url = outputURL.appendingPathComponent(location.filePath)
            logDebug("Gen: Creating \(url.path)")
            try rendered.write(to: url)
        }
        try theme.copyAssets(to: outputURL)
    }

    /// Figure out the title for the docs
    func buildDocsTitle(genData: GenData) -> Localized<String> {
        if let configured = titleOpt.value {
            return configured
        }
        let aModuleName = genData.meta.moduleNames.first ?? "Module"
        var flat = aModuleName + " "
        if let moduleVersion = moduleVersionOpt.value {
            flat += "\(moduleVersion) "
        }
        return Localized<String>(unLocalized: flat)
            .append(.localizedOutput(.docs))
    }

    /// Figure out the breadcrumbs-root for the docs
    func buildBreadcrumbRoot(genData: GenData) -> Localized<String> {
        if let configured = breadcrumbsRootOpt.value {
            return configured
        }
        if genData.meta.moduleNames.count == 1 {
            return Localized<String>(unLocalized: genData.meta.moduleNames.first!)
        }
        return .localizedOutput(.index)
    }

    /// Configured things that do not vary page-to-page
    var globalData: [String: Any] {
        var dict = MustacheKey.dict([
            .j2libVersion : Version.j2libVersion,
            .disableSearch : disableSearchOpt.value,
            .hideAttribution: hideAttributionOpt.value
        ])

        if !hideCoverageOpt.value {
            dict[.docCoverage] = 66
        }
        if let customHead = customHeadOpt.value {
            dict[.customHead] = customHead
        }

        return dict
    }

    /// Build the localizations menu - links to this same page in all the
    /// localizations we're building for.
    func buildLocalizations(page: MustachePage,
                            currentPathToAssets: String) -> [[String: Any]] {
        Localizations.shared.all.map { loc in
            let otherLocation = page.getLocation(languageTag: loc.tag)
            let relativeURL = currentPathToAssets + otherLocation.urlPath
            return MustacheKey.dict([
                .title : "\(loc.flag) \(loc.label)",
                .active : loc.tag == page.languageTag,
                .url : relativeURL
            ])
        }
    }
}

// Helpers to deal with the actual filesystem location of pages, taking the
// localization settings into account.
struct MustachePageLocation {
    /// Path relative to docroot
    let filePath: String
    /// URL-encoded path relative to docroot
    var urlPath: String { filePath.urlPathEncoded }
    /// Empty string or ends in '/'
    let reversePath: String
}

extension MustachePage {
    /// Work out where this page is in a particular language.
    /// If `languageTag` is `nil` then it uses the page's own language.
    func getLocation(languageTag: String? = nil) -> MustachePageLocation {
        let tag = languageTag ?? self.languageTag
        var locationPath = ""
        if tag != Localizations.shared.main.tag {
            locationPath = "\(tag)/"
        }
        let fullPath = locationPath + filepath
        let reversePath = String(repeating: "../", count: fullPath.directoryNestingDepth)
        return MustachePageLocation(filePath: fullPath, reversePath: reversePath)
    }
}
