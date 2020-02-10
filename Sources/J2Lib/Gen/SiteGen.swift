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

        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            try FileManager.default.removeItem(at: outputURL)
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        theme.setGlobalData(globalData)

        var pageIterator = genData.makeIterator(fileExt: theme.fileExtension)

        while let page = pageIterator.next() {
            var url = outputURL
            var depth = 0
            if page.languageTag != Localizations.shared.main.tag {
                url.appendPathComponent(page.languageTag)
                depth = 1
            }
            url.appendPathComponent(page.filepath)
            depth += page.filepath.directoryNestingDepth

            var mustacheData = page.data
            mustacheData[.pathToAssets] = String(repeating: "../", count: depth)

            logDebug("Gen: Rendering template for \(page.data[.pageTitle] ?? "??")")
            let rendered = try theme.renderTemplate(data: mustacheData)

            logDebug("Gen: Creating \(url.path)")
            try rendered.write(to: url)
        }
        try theme.copyAssets(to: outputURL)
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
}
