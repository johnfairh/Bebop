//
//  GenCodeHost.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Yams

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
            throw OptionsError(.localized(.errCfgChostBoth))
        }
        publish.registerCodeHostItemURLForLocation(self.locationURL)
    }

    private static let CUSTOM_SUB_LINE = "%LINE"
    private static let CUSTOM_SUB_START_LINE = "%LINE1"
    private static let CUSTOM_SUB_END_LINE = "%LINE2"

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
                !singleLineFormat.contains(CUSTOM_SUB_LINE) {
                throw OptionsError(.localized(.errCfgChostSingleFmt, CUSTOM_SUB_LINE))
            }
            if let multiLineFormat = multiLineFormatOpt.value,
                !multiLineFormat.contains(CUSTOM_SUB_START_LINE) ||
                    !multiLineFormat.contains(CUSTOM_SUB_END_LINE) {
                throw OptionsError(.localized(.errCfgChostMultiFmt,
                                              CUSTOM_SUB_START_LINE,
                                              CUSTOM_SUB_END_LINE))
            }
        }

        func findMediaPath(published: Published) throws -> String {
            guard let imageName = imageNameOpt.value else {
                throw OptionsError(.localized(.errCfgChostMissingImage))
            }

            guard let mediaPath = published.urlPathForMedia(imageName) else {
                throw OptionsError(.localized(.errCfgChostBadImage, imageName))
            }
            return mediaPath
        }
    }

    private var parser: Parser?
    private var customImagePath: String?

    func checkOptionsPhase2(published: Published) throws {
        guard let customYaml = codeHostCustomOpt.value else {
            return
        }
        parser = try Parser(yaml: customYaml)
        customImagePath = try parser?.findMediaPath(published: published)
    }

    /// Item codehost link builder, invoked from GenPages
    /// Haven't localized this because it just glues URL text together - need a more templately solution
    /// and a real-world implementation.
    func locationURL(location: DefLocation) -> String? {
        nil
    }

    // Site-builder getters

    /// Special case: --code-host-url without --code-host means 'github'
    var isGitHub: Bool {
        codeHostOpt.value.flatMap { $0 == .github } ?? (published.codeHostFallbackURL != nil)
    }
    var isGitLab: Bool    { codeHostOpt.value.flatMap { $0 == .gitlab } ?? false }
    var isBitBucket: Bool { codeHostOpt.value.flatMap { $0 == .bitbucket } ?? false }

    // todo: item menu text

    var custom: MustacheDict? {
        nil
//        guard let parser = parser, let customImagePath = customImagePath else {
//            return nil
//        }
//        var dict = MustacheDict()
//        return dict
    }
}
