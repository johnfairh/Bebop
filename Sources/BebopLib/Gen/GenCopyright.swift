//
//  GenCopyright.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import Maaku

struct GenCopyright: Configurable {
    let copyrightOpt = LocStringOpt(l: "custom-copyright").help("COPYRIGHT_MARKDOWN")
    let authorNameOpt = LocStringOpt(l: "author-name").help("AUTHOR_NAME")
    let authorURLOpt = StringOpt(l: "author-url").help("URL")

    let oldCopyrightOpt: AliasOpt
    let oldAuthorOpt: AliasOpt

    init(config: Config) {
        oldCopyrightOpt = AliasOpt(realOpt: copyrightOpt, l: "copyright")
        oldAuthorOpt = AliasOpt(realOpt: authorNameOpt, l: "author")
        config.register(self)
    }

    public func checkOptions(publish: PublishStore) throws {
        publish.authorName = authorNameOpt.value
    }

    /// Figure out some text for the author details depending on what they supplied.
    private var authorText: Localized<String> {
        if let authorName = authorNameOpt.value {
            if let authorURL = authorURLOpt.value {
                return authorName.mapValues { name in
                    #" <a href="\#(authorURL)" target="_blank" rel="external">\#(name)</a>"#
                }
            }
            return Localized<String>(unlocalized: " ") + authorName
        }
        return .init(unlocalized: "")
    }

    /// Generate the copyright statement from user or made up.
    func generate() -> RichText {
        if let userCopyright = copyrightOpt.value {
            return format(copyright: userCopyright)
        }
        let year: Int
        let dateNow: String
        // Fix for test reproducability
        if ProcessInfo.processInfo.environment["BEBOP_STATIC_DATE"] != nil {
            year = 9999
            dateNow = "today"
        } else {
            // Use the user's locale settings for this
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            let now = Date()
            year = Calendar.current.component(.year, from: now)
            dateNow = dateFormatter.string(from: now)
        }
        let locCopyright = Localized<String>.localizedOutput(.copyright, year, authorText, dateNow)
        return format(copyright: locCopyright)
    }

    private func format(copyright: Localized<String>) -> RichText {
        var richText = RichText(copyright)
        richText.format(CMDocument.format)
        return richText
    }
}
