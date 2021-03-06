//
//  GatherLocalize.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// A type to localize doc comments
final class GatherLocalize: GatherDefVisitor, Configurable {
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

    /// One-time initialization from Gather - track down the bundles we'll need
    func initialize() throws {
        let localizations = Localizations.shared
        docCommentLanguage = docCommentLanguageOpt.value ?? localizations.main.tag
        targetLanguages = Set(localizations.allTags)
        defaultLanguage = localizations.main.tag

        var bundleLanguages = targetLanguages
        bundleLanguages.remove(docCommentLanguage)
        guard !bundleLanguages.isEmpty else {
            logDebug("Gather: No doc comment localization, no alternate localizations.")
            return
        }
        guard let languagesURL = docCommentLanguageDirOpt.value else {
            logDebug("Gather: No doc comment localization, language dir not set.")
            return
        }

        bundleLanguages.forEach { language in
            let bundleURL = languagesURL.appendingPathComponent(language)
            guard let bundle = Bundle(url: bundleURL) else {
                logWarning(.wrnNoCommentMissing, language, bundleURL.path)
                return
            }
            logDebug("Found doc comment translation bundle for '\(language)'.")
            docCommentBundles[language] = bundle
        }
    }

    /// Find a key translated for some language, implementing the "fallback to default" part.
    func markdown(forKey key: String, language: String) -> Markdown? {
        let eyecatcher = "EYECATCH£R"
        guard let bundle = docCommentBundles[language],
            // What a terrible API this is.
            case let translated: String = bundle.localizedString(forKey: key, value: eyecatcher, table: "QuickHelp"),
            translated != eyecatcher else {

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

    /// Apply the localization garnishing to the def.
    ///
    /// This means set the `translatedDocs` field according to the config options: at minimum
    /// this means `{"en": parsedDocs}`.  On output, etither the docs are empty or have something
    /// for each language tag in the localizations list.
    func visit(def: GatherDef, parents: [GatherDef]) throws {
        guard let documentation = def.documentation else {
            return
        }

        var translatedDocs = LocalizedDefDocs()
        var languagesToDo = targetLanguages

        if def.localizationKey != nil {
            Stats.inc(.gatherLocalizationKey)
        }

        // Start with what we have already
        if let native = languagesToDo.remove(docCommentLanguage) {
            translatedDocs.set(tag: native, docs: documentation)
        }

        // Now try each remaining, substituting native if anything is wrong
        languagesToDo.forEach { language in
            if let localizationKey = def.localizationKey,
                let md = markdown(forKey: localizationKey, language: language),
                case let builder = MarkdownBuilder(markdown: md, source: .docComment),
                let langDocs = builder.build() {
                translatedDocs.set(tag: language, docs: langDocs)
                Stats.inc(.gatherLocalizationSuccess)
            } else {
                translatedDocs.set(tag: language, docs: documentation)
                Stats.inc(.gatherLocalizationFailure)
            }
        }

        def.translatedDocs = translatedDocs
    }
}
