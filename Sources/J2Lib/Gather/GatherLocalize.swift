//
//  GatherLocalize.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// A type to localize doc comments
final class GatherLocalize: GatherGarnish, Configurable {
    let docCommentLanguageOpt = StringOpt(l: "doc-comment-language").help("LANGUAGETAG")
    let docCommentLanguageDirOpt = PathOpt(l: "doc-comment-languages-directory").help("DIRPATH")

    var docCommentBundles = Localized<Bundle>()

    var targetLanguages = Set<String>()
    var defaultLanguage = ""
    var docCommentLanguage = ""

    var docCommentsAreDefaultLanguage: Bool {
        defaultLanguage == docCommentLanguage
    }

    init(config: Config) {
        config.register(self)
    }

    public func checkOptions() throws {
        try docCommentLanguageDirOpt.checkIsDirectory()
    }

    func setLocalizations(_ localizations: Localizations) {
        docCommentLanguage = docCommentLanguageOpt.value ?? localizations.main.tag
        targetLanguages = Set(localizations.allTags)
        defaultLanguage = localizations.main.tag

        var bundleLanguages = targetLanguages
        bundleLanguages.remove(docCommentLanguage)
        guard !bundleLanguages.isEmpty else {
            return
        }
        guard let languagesURL = docCommentLanguageDirOpt.value else {
            logWarning("Doc comment translation required but --doc-comment-languages-directory not set.")
            return
        }
        bundleLanguages.forEach { language in
            let bundleURL = languagesURL.appendingPathComponent(language)
            guard let bundle = Bundle(url: bundleURL) else {
                logWarning("Doc comment translation to '\(language)' required but cannot open '\(bundleURL.path)'.")
                return
            }
            docCommentBundles[language] = bundle
        }
    }

    func markdown(forKey key: String, language: String) -> Markdown? {
        guard let bundle = docCommentBundles[language],
            case let translated: String = bundle.localizedString(forKey: key, value: nil, table: "QuickHelp"),
            !translated.isEmpty else {

            // Can't resolve.  Fall back to default language unless
            // (a) we're already there; or
            // (b) the source code is the default language.
            if language != defaultLanguage && !docCommentsAreDefaultLanguage {
                return markdown(forKey: key, language: defaultLanguage)
            }
            return nil
        }
        return Markdown(translated)
    }

    func garnish(def: GatherDef) throws {
        guard let documentation = def.documentation else {
            return
        }

        var translatedDocs = Localized<DefMarkdownDocs>()
        var languagesToDo = targetLanguages

        // Start with what we have already
        if let native = languagesToDo.remove(docCommentLanguage) {
            translatedDocs[native] = documentation
        }

        if let localizationKey = def.localizationKey {
            languagesToDo.forEach { language in
                if let md = markdown(forKey: localizationKey, language: language) {
                    let builder = MarkdownBuilder(markdown: md)
                    translatedDocs[language] = builder.build()
                } else {
                    translatedDocs[language] = documentation
                }
            }
        }

        def.translatedDocs = translatedDocs
    }
}
