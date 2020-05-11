//
//  Theme.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import Mustache
import Yams

/// Hate to use the term but this is the theme manager.  It figures out what builtin themes exist
/// and figures out what the user means when they use `--theme`.
struct GenThemes: Configurable {
    let builtInURL: URL
    let builtInNames: [String]

    let themeOpt: PathOpt // set up in init() because need to glob the themesdir for the usage info!!

    var selected: Theme?

    init(config: Config) {
        Mustache.MustacheLogger = { logWarning("Mustache: \($0)") }

        guard let resourceURL = Resources.shared.bundle.resourceURL else {
            preconditionFailure("Resources corrupt, can't find resource URL")
        }
        builtInURL = resourceURL.appendingPathComponent("themes")
        let themeURLs = builtInURL.filesMatching(.all)
        builtInNames = themeURLs.map { $0.lastPathComponent }

        themeOpt = PathOpt(l: "theme")
            .help(builtInNames.joined(separator: " | ") + " | DIRPATH")
        config.register(self)
    }

    /// Have a guess at what the user meant and pick a URL for the theme directory
    var themeURLFromOpt: URL {
        if let name = themeOpt.configStringValue,
            builtInNames.contains(name) {
            return builtInURL.appendingPathComponent(name)
        } else if let userURL = themeOpt.value {
            return userURL
        }
        return builtInURL.appendingPathComponent("fw2020")
    }

    /// Quick check upfront that the theme directory looks sort of plausable
    func checkOptions() throws {
        let themeURL = themeURLFromOpt
        try themeURL.checkIsDirectory()
        try themeURL.appendingPathComponent("templates").checkIsDirectory()
    }

    /// Resolve the theme
    func select() throws -> Theme {
        let themeURL = themeURLFromOpt
        if FileManager.default.fileExists(atPath: themeURL.appendingPathComponent(Theme.YAML_FILENAME).path) {
            return try Theme(url: themeURLFromOpt)
        }
        logInfo(.msgJazzyTheme)
        return try JazzyTheme(url: themeURL)
    }

    /// Extensions - bundles of stuff we don't want to always include but apply cross-theme
    enum Extension: String {
        /// Client-side rendering of LaTeX
        case katex
        /// Prism support for legacy jazzy themes
        case jazzy_patch
    }

    /// Install a theme extension
    ///
    /// Far too complex because NSFIleManager doesn't natively support a /bin/cp type directory merge copy or copy-overwrite.
    func installExtension(_ ext: Extension, to docsSiteURL: URL) throws {
        let extensionURL = builtInURL
            .deletingLastPathComponent()
            .appendingPathComponent("extensions")
            .appendingPathComponent(ext.rawValue)
        logDebug("Theme: Installing extension \(ext)")
        precondition(extensionURL.isFilesystemDirectory, "Installation broken, can't find \(extensionURL.path).")

        // This is enough to deal with a top-level merge (js, css) but no more...
        try extensionURL.filesMatching(.all).forEach { srcURL in
            let dstURL = docsSiteURL.appendingPathComponent(srcURL.lastPathComponent)
            if !srcURL.isFilesystemDirectory || !dstURL.isFilesystemDirectory {
                try FileManager.default.forceCopyItem(at: srcURL, to: dstURL)
                return
            }
            try FileManager.default.forceCopyContents(of: srcURL, to: dstURL)
        }
    }
}

/// A particular docs theme.
///
/// Knows where it is in the filesystem and how to read its config file.
/// Owns the mustache template and interface
class Theme {
    static let YAML_FILENAME = "theme.yaml"

    /// Parser for the theme.yaml config file
    private struct Parser {
        let mustacheRootOpt = StringOpt(y: "mustache_root").def("doc.mustache")
        let fileExtensionOpt = StringOpt(y: "file_extension").def(".html")
        let scssFilenamesOpt = StringListOpt(y: "scss_filenames")
        let localizedStringsOpt = StringOpt(y: "localized_strings")
        let defaultLanguageTagOpt = StringOpt(y: "default_language_tag")

        var defaultLanguageTag: String {
            defaultLanguageTagOpt.value ?? Localizations.shared.main.tag
        }

        func parse(themeYaml: String) throws {
            let optsParser = OptsParser()
            optsParser.addOpts(from: self)
            try optsParser.apply(yaml: themeYaml, from: Theme.YAML_FILENAME)
        }
    }

    /// URL to the theme root
    private let url: URL
    /// URL to the root mustache template file
    private let mustacheRootURL: URL
    /// The root mustache template object
    private let template: Template

    /// File extension that the generated output files should be given.  Includes leading period.
    let fileExtension: String

    /// List of scss files in assets/css
    let scssFilenames: [String]

    /// Localized strings for templates
    let localizedStrings: Localized<MustacheDict>

    init(url: URL) throws {
        self.url = url
        logDebug("Theme: checking theme \(url.path)")

        // Must have a templates directory
        let templatesURL = url.appendingPathComponent("templates")
        try templatesURL.checkIsDirectory()

        // May have a yaml - must be valid if exists
        let themeParser = Parser()
        let themeYamlURL = url.appendingPathComponent(Self.YAML_FILENAME)
        if let themeYaml = try? String(contentsOf: themeYamlURL) {
            try themeParser.parse(themeYaml: themeYaml)
        }

        mustacheRootURL = templatesURL.appendingPathComponent(themeParser.mustacheRootOpt.value!)
        fileExtension = themeParser.fileExtensionOpt.value!
        scssFilenames = themeParser.scssFilenamesOpt.value

        logDebug("Theme: loading mustache template")

        template = try Template(URL: mustacheRootURL)

        if let stringsFilename = themeParser.localizedStringsOpt.value {
            logDebug("Theme: loading localized strings from \(stringsFilename)")
            let localizedURL = Localized<URL>(localizingFile: templatesURL.appendingPathComponent(stringsFilename),
                                              languageTag: themeParser.defaultLanguageTag)
            localizedStrings = try localizedURL.mapValues { yamlURL in
                let mapping = try Yams.Node.Mapping.compose(from: yamlURL)
                return Dictionary(uniqueKeysWithValues: try mapping.map { elem in
                    try (elem.0.checkScalarKey().string, elem.1.checkScalar(context: "key").string)
                })
            }
        } else {
            localizedStrings = [:]
        }

        logDebug("Theme: \(fileExtension) \(mustacheRootURL.path)")
    }

    func setGlobalData(_ data: MustacheDict) {
        template.extendBaseContext(data)
    }

    func setDefaultLanguage(_ language: DefLanguage) {
        // overridden in jazzy theme generator
    }

    func renderTemplate(data: MustacheDict, languageTag: String) throws -> Html {
        try Html(template.render(data.merging(localizedStrings.get(languageTag), uniquingKeysWith: {
            throw BBError(.errThemeKeyClash, $0, $1)
        })))
    }

    /// Extensions required by the theme.  Could get from yaml if ever figure out what this means.
    var extensions: [GenThemes.Extension] {
        []
    }

    /// Copy everything from the `assets` directory into the root of the docs site
    func copyAssets(to docsSiteURL: URL) throws {
        logDebug("Theme: copying assets")
        let assetsURL = url.appendingPathComponent("assets")
        guard FileManager.default.fileExists(atPath: assetsURL.path) else {
            return
        }
        try FileManager.default.forceCopyContents(of: assetsURL, to: docsSiteURL)

        if !scssFilenames.isEmpty {
            let cssDirURL = docsSiteURL.appendingPathComponent("css")
            try scssFilenames.forEach {
                try Sass.renderInPlace(scssFileURL: cssDirURL.appendingPathComponent($0))
            }
            try cssDirURL.filesMatching("*.scss").forEach {
                try FileManager.default.removeItem(at: $0)
            }
        }
    }

    /// Copy the theme itself to a new place
    final func copy(to dstURL: URL) throws {
        try FileManager.default.forceCopyContents(of: url, to: dstURL)
    }
}
