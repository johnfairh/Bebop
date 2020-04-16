//
//  Theme.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Mustache

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
        let themeURLs = builtInURL.filesMatching("*")
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
        try Theme(url: themeURLFromOpt)
    }
}

/// A particular docs theme.
///
/// Knows where it is in the filesystem and how to read its config file.
/// Owns the mustache template and interface
struct Theme {
    /// Parser for the theme.yaml config file
    private struct Parser {
        let mustacheRootOpt = StringOpt(y: "mustache_root").def("doc.mustache")
        let fileExtensionOpt = StringOpt(y: "file_extension").def(".html")

        func parse(themeYaml: String) throws {
            let optsParser = OptsParser()
            optsParser.addOpts(from: self)
            try optsParser.apply(yaml: themeYaml)
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

    init(url: URL) throws {
        self.url = url
        logDebug("Theme: checking theme \(url.path)")

        // Must have a templates directory
        let templatesURL = url.appendingPathComponent("templates")
        try templatesURL.checkIsDirectory()

        // May have a yaml - must be valid if exists
        let themeParser = Parser()
        let themeYamlURL = url.appendingPathComponent("theme.yaml")
        if let themeYaml = try? String(contentsOf: themeYamlURL) {
            try themeParser.parse(themeYaml: themeYaml)
        }

        mustacheRootURL = templatesURL.appendingPathComponent(themeParser.mustacheRootOpt.value!)
        fileExtension = themeParser.fileExtensionOpt.value!

        logDebug("Theme: loading mustache template")

        template = try Template(URL: mustacheRootURL)

        logDebug("Theme: \(fileExtension) \(mustacheRootURL.path)")
    }

    func setGlobalData(_ data: MustacheDict) {
        template.extendBaseContext(data)
    }

    func renderTemplate(data: MustacheDict) throws -> Html {
        try Html(template.render(data))
    }

    /// Copy everything from the `assets` directory into the root of the docs siet
    func copyAssets(to docsSiteURL: URL, copier: (URL, URL) throws -> Void) throws {
        logDebug("Theme: copying assets")
        let assetsURL = url.appendingPathComponent("assets")
        guard FileManager.default.fileExists(atPath: assetsURL.path) else {
            return
        }
        let contents = try FileManager.default.contentsOfDirectory(at: assetsURL, includingPropertiesForKeys: [])
        try contents.forEach { srcURL in
            let filename = srcURL.lastPathComponent
            let dstURL = docsSiteURL.appendingPathComponent(filename)
            try copier(srcURL, dstURL)
        }
    }
}
