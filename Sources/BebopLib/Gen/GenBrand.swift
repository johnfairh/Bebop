//
//  GenBrand.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Yams

/// Tiny module to manage the `custom_brand` config stanza.
///
final class GenBrand: Configurable {
    private let customBrandOpt = YamlOpt(y: "custom_brand")

    init(config: Config) {
        config.register(self)
    }

    private struct Parser {
        let imageNameOpt = StringOpt(y: "image_name")
        let altTextOpt = LocStringOpt(y: "alt_text")
        let titleOpt = LocStringOpt(y: "title")
        let urlOpt = LocStringOpt(y: "url")

        init(yaml: Yams.Node) throws {
            let parser = OptsParser()
            parser.addOpts(from: self)
            try parser.apply(mapping: yaml.checkMapping(context: "custom_brand"))
        }

        func findMediaPath(published: Published) throws -> String {
            guard let imageName = imageNameOpt.value else {
                throw BBError(.errCfgBrandMissingImage)
            }

            guard let mediaPath = published.urlPathForMedia(imageName) else {
                throw BBError(.errCfgBrandBadImage, imageName)
            }
            return mediaPath
        }
    }

    private var parser: Parser?

    private(set) var imagePath: String?
    var altText: Localized<String>? { parser?.altTextOpt.value }
    var title: Localized<String>?   { parser?.titleOpt.value }
    var url: Localized<String>?     { parser?.urlOpt.value }

    func checkOptionsPhase2(published: Published) throws {
        guard let customBrandYaml = customBrandOpt.value else {
            return
        }
        parser = try Parser(yaml: customBrandYaml)
        imagePath = try parser?.findMediaPath(published: published)
    }
}
