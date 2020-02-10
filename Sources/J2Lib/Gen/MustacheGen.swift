//
//  MustacheGen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Gubbins to generate a sequence of `MustachePage`s from a `GenData`.
/// This loops over all the pages for every language being produced.
extension GenData {
    public struct Iterator: IteratorProtocol {
        let genData: GenData
        let fileExt: String
        var locIterator: Array<String>.Iterator
        var nextPage: Int
        var currentLanguageTag: String

        init(genData: GenData, fileExt: String) {
            self.genData = genData
            self.fileExt = fileExt
            self.locIterator = Localizations.shared.allTags.makeIterator()
            self.nextPage = 0
            self.currentLanguageTag = locIterator.next()!
        }

        public mutating func next() -> MustachePage? {
            if nextPage == genData.pages.count {
                // done all the pages of the current language
                guard let nextLanguageTag = locIterator.next() else {
                    // No more languages: the end
                    return nil
                }
                currentLanguageTag = nextLanguageTag
                nextPage = 0
            }
            defer { nextPage += 1 }
            return genData.generate(page: nextPage,
                                    languageTag: currentLanguageTag,
                                    fileExt: fileExt)
        }
    }

    public func makeIterator(fileExt: String) -> Iterator {
        Iterator(genData: self, fileExt: fileExt)
    }
}

// MARK: Generate

/// The type fed to the mustache templates to generate a page
public struct MustachePage {
    let languageTag: String
    let filepath: String
    let data: [String : Any]
}

extension Dictionary where Key == String {
    subscript(arg: MustacheKey) -> Value? {
        set { self[arg.rawValue] = newValue }
        get { self[arg.rawValue] }
    }
}

public enum MustacheKey: String {
    // Global, fixed
    case j2libVersion = "j2lib_version"
    case disableSearch = "disable_search"
    case hideAttribution = "hide_attribution"
    case docCoverage = "doc_coverage"
    case customHead = "custom_head"

    // Global, per-page
    case languageTag = "language_tag"
    case pageTitle = "page_title"
    case pathToRoot = "path_to_root" // empty string or ends in "/"
    case toc = "toc"
    // Global, set by SiteGen
    case pathToAssets = "path_to_assets" // empty string or ends in "/"

    // ToC entries
    case title = "title"
    case url = "url"
    case active = "active"
    case children = "children"

    static func dict(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
        Dictionary(uniqueKeysWithValues: pairs.map { ($0.0.rawValue, $0.1) })
    }
}

private func MH(_ pairs: KeyValuePairs<MustacheKey, Any>) -> [String : Any] {
    MustacheKey.dict(pairs)
}

extension GenData {
    public func generate(page: Int, languageTag: String, fileExt: String) -> MustachePage {
        var data = [String: Any]()
        let pg = pages[page]
        let filepath = pg.url.filepath(fileExtension: fileExt)
        data[.languageTag] = languageTag
        data[.pageTitle] = pg.title[languageTag]
        data[.pathToRoot] = pg.url.pathToRoot

        data[.toc] = generateToc(languageTag: languageTag,
                                 fileExt: fileExt,
                                 pageURLPath: pg.url.url(fileExtension: fileExt))

        return MustachePage(languageTag: languageTag, filepath: filepath, data: data)
    }

    /// Generate the table of contents (left nav) for the page.
    /// This is unique for each page because the 'active' element changes and translation.
    func generateToc(languageTag: String, fileExt: String, pageURLPath: String) -> [[String : Any]] {

        func tocList(entries: [TocEntry]) -> [[String : Any]] {
            entries.map { entry in
                let entryURLPath = entry.url.url(fileExtension: fileExt)
                return MH([.title: entry.title[languageTag] ?? "??",
                           .url: entryURLPath,
                           .active: entryURLPath == pageURLPath,
                           .children: tocList(entries: entry.children)])
            }
        }

        return tocList(entries: toc)
    }
}
