//
//  GenSite.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Behaviours for the popopen sections
public enum NestedItemStyle: String, CaseIterable {
    /// All items closed on page-load
    case start_closed
    /// All items open on page-load, can be closed
    case start_open
    /// All items open on page-load, cannot be closed
    case always_open
}

/// Popopen or apple-style
public enum ChildItemStyle: String, CaseIterable {
    /// Nest children in parent
    case nest
    /// Types go on separate pages, methods etc. nest
    case nest_expand_types
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
    let customHeadOpt = StringOpt(l: "custom-head").help("HTML")

    let titleOpt = LocStringOpt(l: "title").help("TITLE")
    let moduleVersionOpt = StringOpt(l: "module-version").help("VERSION")
    let breadcrumbsRootOpt = LocStringOpt(l: "breadcrumbs-root").help("TITLE")

    let childItemStyleOpt = EnumOpt<ChildItemStyle>(l: "child-item-style").def(.nest)
    let nestedItemStyleOpt = EnumOpt<NestedItemStyle>(l: "nested-item-style").def(.start_closed)

    let oldHideCoverageOpt: AliasOpt
    let oldCustomHeadOpt: AliasOpt
    let oldDisableSearchOpt: AliasOpt

    private let published: Config.Published

    var outputURL: URL { outputOpt.value! }
    var childItemStyle: ChildItemStyle { childItemStyleOpt.value! }
    var nestedItemStyle: NestedItemStyle { nestedItemStyleOpt.value! }

    let themes: GenThemes
    let copyright: GenCopyright

    public init(config: Config) {
        themes = GenThemes(config: config)
        copyright = GenCopyright(config: config)

        oldHideCoverageOpt = AliasOpt(realOpt: hideCoverageOpt, l: "hide-documentation-coverage")
        oldCustomHeadOpt = AliasOpt(realOpt: customHeadOpt, l: "head")
        oldDisableSearchOpt = AliasOpt(realOpt: hideSearchOpt, l: "disable-search")

        published = config.published

        config.register(self)
    }

    public func checkOptions(published: Config.Published) throws {
        published.childItemStyle = childItemStyle
    }

    /// Final site generation
    public func generateSite(genData: GenData) throws {
        let theme = try themes.select()

        logInfo(.localized(.msgGeneratingDocs))

        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            try FileManager.default.removeItem(at: outputURL)
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        theme.setGlobalData(buildGlobalData(genData: genData))

        try generatePages(genData: genData, fileExt: theme.fileExtension) { location, data in
            logDebug("Gen: Rendering template for \(data[.primaryPageTitle]!)")
            let rendered = try theme.renderTemplate(data: data)

            let url = outputURL.appendingPathComponent(location.filePath)
            logDebug("Gen: Creating \(url.path)")
            try rendered.write(to: url)
        }

        try theme.copyAssets(to: outputURL)
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

    /// Factored out page generation
    private func generatePages(genData: GenData,
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

        if let customHead = customHeadOpt.value {
            dict[.customHead] = customHead
        }

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
