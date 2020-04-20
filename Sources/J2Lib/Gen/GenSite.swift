//
//  GenSite.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Behaviours for the popopen sections
enum NestedItemStyle: String, CaseIterable {
    /// All items closed on page-load
    case start_closed
    /// All items open on page-load, can be closed
    case start_open
    /// All items open on page-load, cannot be closed
    case always_open
}

/// Popopen or apple-style
enum ChildItemStyle: String, CaseIterable {
    /// Nest children in parent
    case nested
    /// Types go on separate pages, methods etc. nest
    case nested_separate_types
    /// Page per definition, no nesting
    case separate
}

/// `GenSite` produces docs output data from an `Item` forest.
///
/// tbd whether we need the pagegen / sitegen split - just stubs really
public struct GenSite: Configurable {
    let outputOpt = PathOpt(s: "o", l: "output").help("DIRPATH").def("docs")
    let cleanOpt = BoolOpt(s: "c", l: "clean")

    let hideSearchOpt = BoolOpt(l: "hide-search")
    let hideAttributionOpt = BoolOpt(l: "hide-attribution")
    let hideCoverageOpt = BoolOpt(l: "hide-coverage")
    let hideAvailabilityOpt = BoolOpt(l: "hide-availability")
    let hidePaginationOpt = BoolOpt(l: "hide-pagination")
    let customHeadOpt = StringOpt(l: "custom-head").help("HTML")

    let titleOpt = LocStringOpt(l: "title").help("TITLE")
    let moduleVersionOpt = StringOpt(l: "module-version").help("VERSION")
    let breadcrumbsRootOpt = LocStringOpt(l: "breadcrumbs-root").help("TITLE")

    let childItemStyleOpt = EnumOpt<ChildItemStyle>(l: "child-item-style").def(.nested)
    let nestedItemStyleOpt = EnumOpt<NestedItemStyle>(l: "nested-item-style").def(.start_closed)

    let deploymentURLOpt = URLOpt(l: "deployment-url").help("SITEURL")
    let docsetFeedURLOpt = URLOpt(l: "docset-feed-url").help("XMLFEEDURL")

    let oldDashURLAlias: AliasOpt
    let oldRootURLAlias: AliasOpt
    let oldHideCoverageOpt: AliasOpt
    let oldCustomHeadOpt: AliasOpt
    let oldDisableSearchOpt: AliasOpt

    private let published: Published

    var outputURL: URL { outputOpt.value! }
    var childItemStyle: ChildItemStyle { childItemStyleOpt.value! }
    var nestedItemStyle: NestedItemStyle { nestedItemStyleOpt.value! }

    let themes: GenThemes
    let media: GenMedia
    let copyright: GenCopyright
    let search: GenSearch
    let badge: GenBadge
    let brand: GenBrand
    let codeHost: GenCodeHost
    let docset: GenDocset

    public init(config: Config) {
        themes = GenThemes(config: config)
        media = GenMedia(config: config)
        copyright = GenCopyright(config: config)
        search = GenSearch(config: config)
        badge = GenBadge(config: config)
        brand = GenBrand(config: config)
        codeHost = GenCodeHost(config: config)
        docset = GenDocset(config: config)

        oldHideCoverageOpt = AliasOpt(realOpt: hideCoverageOpt, l: "hide-documentation-coverage")
        oldCustomHeadOpt = AliasOpt(realOpt: customHeadOpt, l: "head")
        oldDisableSearchOpt = AliasOpt(realOpt: hideSearchOpt, l: "disable-search")
        oldDashURLAlias = AliasOpt(realOpt: docsetFeedURLOpt, l: "dash_url") // _ intentional ...
        oldRootURLAlias = AliasOpt(realOpt: deploymentURLOpt, l: "root-url")

        published = config.published

        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        publish.childItemStyle = childItemStyle
        publish.moduleVersion = moduleVersionOpt.value
    }

    /// Final site generation.
    /// Site is generated from `genData` only; `items` used for search index and docset.
    public func generateSite(genData: GenData, items: [Item]) throws {
        let theme = try themes.select()

        logInfo(.localized(.msgGeneratingDocs))

        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        theme.setGlobalData(buildGlobalData(genData: genData))

        try generatePages(genData: genData, fileExt: theme.fileExtension) { location, data in
            logDebug("Gen: Rendering template for \(data[.primaryPageTitle]!)")
            let rendered = try theme.renderTemplate(data: data)
            let url = outputURL.appendingPathComponent(location.filePath)
            logDebug("Gen: Creating \(url.path)")
            try rendered.html.write(to: url)
        }

        func copier(from: URL, to: URL) throws {
            if FileManager.default.fileExists(atPath: to.path) {
                try FileManager.default.removeItem(at: to)
            }
            try FileManager.default.copyItem(at: from, to: to)
        }

        if !hideSearchOpt.value {
            logInfo(.localized(.msgSearchProgress))
            try search.buildIndex(items: items)
        }

        logInfo(.localized(.msgCopyProgress))

        try Localizations.shared.allTags.forEach { tag in
            let docRoot = outputURL.appendingPathComponent(tag.languageTagPathComponent)
            try media.copyMedia(docRoot: docRoot, languageTag: tag, copier: copier)

            if !hideSearchOpt.value {
                try search.writeIndex(docRootURL: docRoot, languageTag: tag)
            }

            if !hideCoverageOpt.value {
                try badge.write(docRootURL: docRoot, languageTag: tag)
            }
        }

        try theme.copyAssets(to: outputURL, copier: copier)
    }

    /// JSON instead of the website
    public func generateJSON(genData: GenData) throws -> String {
        var siteData = [MustacheDict]()
        let globals = buildGlobalData(genData: genData)

        generatePages(genData: genData, fileExt: ".html" /* ?? */) { _, data in
            var data = data
            data.merge(globals, uniquingKeysWith: { a, b in a })
            siteData.append(data)
        }

        return try JSON.encode(data: siteData)
    }

    /// Passthrough to generate the docset
    public func generateDocset(items: [Item]) throws {
        try docset.generate(outputURL: outputURL, deploymentURL: deploymentURLOpt.value, items: items)
    }

    /// Factored out page generation.  Internal for tests.
    func generatePages(genData: GenData,
                       fileExt: String,
                       callback: (MustachePageLocation, MustacheDict) throws -> ()) rethrows {
        let docsTitle = buildDocsTitle()
        let breadcrumbsRoot = buildBreadcrumbsRoot()

        let copyrightText = copyright.generate()

        var pageIterator = genData.makeIterator(fileExt: fileExt)

        while let page = pageIterator.next() {
            let location = page.getLocation()

            var mustacheData = page.data
            mustacheData[.pathToAssets] = location.reversePath
            mustacheData[.pathFromRoot] = page.filepath.urlPathEncoded
            mustacheData[.docsTitle] = docsTitle.get(page.languageTag)
            mustacheData[.copyrightHtml] = copyrightText.html.get(page.languageTag).html
            mustacheData[.breadcrumbsRoot] = breadcrumbsRoot.get(page.languageTag)
            mustacheData.maybe(.brandImagePath, brand.imagePath?.urlPathEncoded)
            mustacheData.maybe(.brandTitle, brand.title?.get(page.languageTag))
            mustacheData.maybe(.brandAltText, brand.altText?.get(page.languageTag))
            mustacheData.maybe(.brandURL, brand.url?.get(page.languageTag))
            mustacheData.maybe(.codehostCustom, codeHost.custom(languageTag: page.languageTag))
            mustacheData.maybe(.codehostDefLink, codeHost.defLinkText.get(page.languageTag))

            if hidePaginationOpt.value {
                mustacheData.removeValue(forKey: MustacheKey.pagination.rawValue)
            }

            if Localizations.shared.all.count > 1 {
                mustacheData[.pageLocalization] =
                    Localizations.shared.localization(languageTag: page.languageTag).flag
            }

            try callback(location, mustacheData)
        }
    }

    /// Figure out the title for the docs
    func buildDocsTitle() -> Localized<String> {
        if let configured = titleOpt.value {
            return configured
        }
        let aModuleName = published.moduleNames.first ?? "Module"
        var flat = aModuleName + " "
        if let moduleVersion = moduleVersionOpt.value {
            flat += "\(moduleVersion) "
        }
        return Localized<String>(unlocalized: flat) + .localizedOutput(.docs)
    }

    /// Figure out the breadcrumbs-root for the docs
    func buildBreadcrumbsRoot() -> Localized<String> {
        if let configured = breadcrumbsRootOpt.value {
            return configured
        }
        if published.moduleNames.count == 1 {
            return Localized<String>(unlocalized: published.moduleNames.first!)
        }
        return .localizedOutput(.index)
    }

    /// Configured things that do not vary page-to-page
    func buildGlobalData(genData: GenData) -> MustacheDict {
        let isDualLanguage = genData.meta.languages.count == 2
        let neverCollapse = nestedItemStyle == .always_open || childItemStyle == .separate

        var dict = MustacheKey.dict([
            .j2libVersion : Version.j2libVersion,
            .hideSearch : hideSearchOpt.value,
            .hideAttribution: hideAttributionOpt.value,
            .hideAvailability: hideAvailabilityOpt.value,
            .itemCollapseOpen: nestedItemStyle == .start_open,
            .itemCollapseNever: neverCollapse,
            .itemNest: childItemStyle != .separate,
            .dualLanguage: isDualLanguage,
            .defaultLanguage: genData.meta.defaultLanguage.cssName
        ])

        if hideSearchOpt.value && !isDualLanguage && neverCollapse {
            dict[.hideActions] = true
        }

        if !hideCoverageOpt.value {
            dict[.docCoverage] = Stats.coverage
        }

        dict.maybe(.customHead, customHeadOpt.value)

        if Localizations.shared.all.count > 1 {
            dict[.localizations] =
                Localizations.shared.all.map { loc in
                    MustacheKey.dict([
                        .title : "\(loc.flag) \(loc.label)",
                        .tag: loc.tag,
                        .tagPath: loc.tag.languageTagPathComponent
                    ])
            }
        }

        if codeHost.isGitHub {
            dict[.codehostGitHub] = true
        } else if codeHost.isGitLab {
            dict[.codehostGitLab] = true
        } else if codeHost.isBitBucket {
            dict[.codehostBitBucket] = true
        }

        // Put the docset feed at either (a) where they asked for it, or
        //                               (b) figured out relative to deployment URL
        let docsetFeedURL = docsetFeedURLOpt.value ??
            (deploymentURLOpt.value.flatMap { docset.feedURLFrom(deploymentURL: $0) })

        dict.maybe(.docsetURL, docsetFeedURL?.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics))

        return dict
    }
}

// Helpers to deal with the actual filesystem location of pages, taking the
// localization settings into account.
struct MustachePageLocation {
    /// Path relative to docroot
    let filePath: String
    /// Empty string or ends in '/'
    let reversePath: String
}

extension MustachePage {
    /// Work out where this page is in its language
    func getLocation() -> MustachePageLocation {
        let locPathComponent = self.languageTag.languageTagPathComponent
        let fullPath = locPathComponent + filepath
        let reversePath = String(repeating: "../", count: fullPath.directoryNestingDepth)
        return MustachePageLocation(filePath: fullPath, reversePath: reversePath)
    }
}

extension String {
    var languageTagPathComponent: String {
        let defaultTag = Localizations.shared.main.tag
        if defaultTag == self {
            return ""
        }
        return "\(self)/"
    }
}
