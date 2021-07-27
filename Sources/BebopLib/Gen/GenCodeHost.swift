//
//  GenCodeHost.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Yams
import Foundation

enum CodeHost: String, CaseIterable {
    case github
    case gitlab
    case bitbucket
}

/// A codehost is a thing like github where the source code to the module lives.
///
/// Two UI elements configured here:
/// - titlebar image link to the root of the repo.
/// - per-item deep link to the source file that generated the item.
///
/// Presets (images, URL formats) for GitHub, GitLab, BitBucket.
/// And a custom route for private installations or other weird platforms.
///
/// Most of this module is configuration checking and massaging.
/// The per-item URL generation is a bit complicated because of the
/// different formats.
final class GenCodeHost: Configurable {
    let codeHostOpt = EnumOpt<CodeHost>(l: "code-host")
    let codeHostCustomOpt = YamlOpt(y: "custom_code_host")
    let published: Published

    init(config: Config) {
        published = config.published
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        if codeHostOpt.configured && codeHostCustomOpt.configured {
            throw BBError(.errCfgChostBoth)
        }
        publish.registerCodeHostItemURLForLocation(self.locationURL)
    }

    private struct Parser {
        let imageNameOpt = StringOpt(y: "image_name")
        let altTextOpt = LocStringOpt(y: "alt_text")
        let titleOpt = LocStringOpt(y: "title")
        let singleLineFormatOpt = StringOpt(y: "single_line_format")
        let multiLineFormatOpt = StringOpt(y: "multi_line_format")
        let itemMenuTextOpt = LocStringOpt(y: "item_menu_text")

        init(yaml: Yams.Node) throws {
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: yaml.checkMapping(context: "custom_code_host"))

            if let singleLineFormat = singleLineFormatOpt.value,
                !singleLineFormat.contains(CustomLineFormatter.LINE_PATTERN) {
                throw BBError(.errCfgChostSingleFmt, CustomLineFormatter.LINE_PATTERN)
            }
            if let multiLineFormat = multiLineFormatOpt.value,
                !multiLineFormat.contains(CustomLineFormatter.START_LINE_PATTERN) ||
                    !multiLineFormat.contains(CustomLineFormatter.END_LINE_PATTERN) {
                throw BBError(.errCfgChostMultiFmt,
                              CustomLineFormatter.START_LINE_PATTERN,
                              CustomLineFormatter.END_LINE_PATTERN)
            }

            if singleLineFormatOpt.configured != multiLineFormatOpt.configured {
                throw BBError(.errCfgChostMissingFmt)
            }
        }

        func findMediaPath(published: Published) throws -> String {
            guard let imageName = imageNameOpt.value else {
                throw BBError(.errCfgChostMissingImage)
            }

            guard let mediaPath = published.urlPathForMedia(imageName) else {
                throw BBError(.errCfgChostBadImage, imageName)
            }
            return mediaPath
        }
    }

    private var parser: Parser?
    private var customImagePath: String?
    private var lineFormatter: LineFormatter?

    func checkOptionsPhase2(published: Published) throws {
        if let customYaml = codeHostCustomOpt.value {
            parser = try Parser(yaml: customYaml)
            customImagePath = try parser?.findMediaPath(published: published)
        }
        lineFormatter = createLineFormatter()
    }

    // MARK: Item Link Builder

    // How is this so much code!

    private func createLineFormatter() -> LineFormatter {
        if let singleLineTemplate = parser?.singleLineFormatOpt.value,
            let multiLineTemplate = parser?.multiLineFormatOpt.value {
            return CustomLineFormatter(singleLineTemplate: singleLineTemplate,
                                       multiLineTemplate: multiLineTemplate)
        }
        if isBitBucket {
            return BitBucketLineFormatter()
        }
        return GitHubLineFormatter()
    }

    /// Item codehost link builder, invoked from `GenPages` via `Publish`
    /// Haven't localized this because it just glues URL text together - need a more templately solution
    /// and a real-world implementation.
    func locationURL(location: DefLocation) -> String? {
        let module = published.module(location.moduleName)

        guard let filePathname = location.filePathname,
            let codeHostFilePrefix = module.codeHostFilePrefix,
            let moduleSourceDirPath = module.sourceDirectory?.path,
            filePathname.hasPrefix(moduleSourceDirPath) else {
            return nil
        }
        var url = codeHostFilePrefix +
            String(filePathname.dropFirst(moduleSourceDirPath.count)).urlPathEncoded
        if let lineSuffix = lineFormatter?.format(startLine: location.firstLine, endLine: location.lastLine) {
            url += "#\(lineSuffix)"
        }
        return url
    }

    // MARK: Site-builder

    /// Special case: --code-host-url without --code-host or custom means 'github'
    var isGitHub: Bool {
        if let codeHost = codeHostOpt.value {
            return codeHost == .github
        }
        return !codeHostCustomOpt.configured && published.codeHostFallbackURL != nil
    }

    var isGitLab: Bool    { codeHostOpt.value.flatMap { $0 == .gitlab } ?? false }
    var isBitBucket: Bool { codeHostOpt.value.flatMap { $0 == .bitbucket } ?? false }

    func custom(languageTag: String) -> MustacheDict? {
        guard let parser = parser, let customImagePath = customImagePath else {
            return nil
        }
        var dict = MustacheDict()
        dict.maybe(.codehostImagePath, customImagePath.urlPathEncoded)
        dict.maybe(.codehostAltText, parser.altTextOpt.value?.get(languageTag))
        dict.maybe(.codehostTitle, parser.titleOpt.value?.get(languageTag))
        return dict
    }

    var defLinkText: Localized<String> {
        if let customText = parser?.itemMenuTextOpt.value {
            return customText
        }
        if isBitBucket {
            return .localizedOutput(.showOnBitBucket)
        }
        if isGitLab {
            return .localizedOutput(.showOnGitLab)
        }
        return .localizedOutput(.showOnGitHub)
    }
}

// MARK: LineFormatter empire

protocol LineFormatter {
    func formatOne(line: Int) -> String
    func formatRange(startLine: Int, endLine: Int) -> String
}

extension LineFormatter {
    /// Handle the cases and return the right format
    func format(startLine: Int?, endLine: Int?) -> String? {
        guard let startLine = startLine else {
            return nil
        }
        if let endLine = endLine,
            endLine != startLine {
            return formatRange(startLine: startLine, endLine: endLine)
        }
        return formatOne(line: startLine)
    }
}

struct GitHubLineFormatter: LineFormatter {
    func formatOne(line: Int) -> String {
        "L\(line)"
    }

    func formatRange(startLine: Int, endLine: Int) -> String {
        "L\(startLine)-L\(endLine)"
    }
}

struct BitBucketLineFormatter: LineFormatter {
    func formatOne(line: Int) -> String {
        "lines-\(line)"
    }

    func formatRange(startLine: Int, endLine: Int) -> String {
        "lines-\(startLine):\(endLine)"
    }
}

struct CustomLineFormatter: LineFormatter {
    let singleLineTemplate: String
    let multiLineTemplate: String

    static let LINE_PATTERN = "%LINE"
    static let START_LINE_PATTERN = "%LINE1"
    static let END_LINE_PATTERN = "%LINE2"

    func formatOne(line: Int) -> String {
        singleLineTemplate.replacingOccurrences(of: Self.LINE_PATTERN, with: String(line))
    }

    func formatRange(startLine: Int, endLine: Int) -> String {
        multiLineTemplate
            .replacingOccurrences(of: Self.START_LINE_PATTERN, with: String(startLine))
            .replacingOccurrences(of: Self.END_LINE_PATTERN, with: String(endLine))
    }
}
