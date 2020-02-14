//
//  Format.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Format: Configurable {
    let readmeOpt = PathOpt(l: "readme").help("FILEPATH")

    private var configPublished: Config.Published

    public init(config: Config) {
        configPublished = config.published
        config.register(self)
    }

    public func checkOptions(published: Config.Published) throws {
        try readmeOpt.checkIsFile()
    }

    public func format(items: [Item]) throws -> [Item] {
        let allItems = items + [try createReadme()]
        URLFormatter().walk(items: allItems)
        MarkdownFormatter(language: .swift).walk(items: allItems)
        return allItems
    }

    /// Go discover the readme.
    func createReadme() throws -> ReadmeItem {
        if let readmeURL = readmeOpt.value {
            logDebug("Format: Using configured readme '\(readmeURL.path)'")
            return ReadmeItem(content: try Localized<Markdown>(localizingFile: readmeURL))
        }

        let srcDirURL = configPublished.sourceDirectoryURL ?? FileManager.default.currentDirectory
        for guess in ["README.md", "README.markdown", "README.mdown", "README"] {
            let guessURL = srcDirURL.appendingPathComponent(guess)
            if FileManager.default.fileExists(atPath: guessURL.path) {
                logDebug("Format: Using found readme '\(guessURL.path)'.")
                return ReadmeItem(content: try Localized<Markdown>(localizingFile: guessURL))
            }
        }
        logDebug("Format: Can't find anything that looks like a readme, making something up.")
        return ReadmeItem(content: Localized<Markdown>(unlocalized: Markdown("Read ... me?")))
    }
}
