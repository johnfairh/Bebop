//
//  DocsData.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// A somewhat-normalized pure-ish data structure containing everything
/// required to render the parts of the site that change page-to-page.
///
/// Dumped for the `docs-summary-json` product.
public final class GenData: Encodable {
    public struct Meta: Encodable {
        /// Version of this program
        public let version: String
    }
    public let meta: Meta
    public struct TocEntry: Encodable {
        public let url : URLPieces
        public let title: Localized<String>
        public let children: [TocEntry]
    }
    public let toc: [TocEntry]
    public struct Page: Encodable {
        public let url: URLPieces
        public let title: Localized<String>
        public let tabTitlePrefix: Bool
        public let isGuide: Bool
        // breadcrumbs
        public let swiftDeclaration: Html?
//        public let availability: [String]
        public let abstract: Localized<Html>?
        public let overview: Localized<Html>?
        // topics

        /// Def init
        public init(defURL: URLPieces,
                    title: Localized<String>,
                    abstract: Localized<Html>?,
                    overview: Localized<Html>?,
                    swiftDeclaration: Html?) {
            self.url = defURL
            self.title = title
            self.tabTitlePrefix = true
            self.isGuide = false
            self.abstract = abstract
            self.overview = overview
            self.swiftDeclaration = swiftDeclaration
        }

        /// Group init
        public init(groupURL: URLPieces, title: Localized<String>, overview: Localized<Html>?) {
            self.url = groupURL
            self.title = title
            self.tabTitlePrefix = true
            self.isGuide = false
            self.abstract = nil
            self.overview = overview
            self.swiftDeclaration = nil
        }

        /// Guide init
        public init(guideURL: URLPieces, title: Localized<String>, isReadme: Bool, overview: Localized<Html>?) {
            self.url = guideURL
            self.title = title
            self.tabTitlePrefix = !isReadme
            self.isGuide = true
            self.abstract = nil
            self.overview = overview
            self.swiftDeclaration = nil
        }
    }
    public let pages: [Page]

    public init(meta: Meta, toc: [TocEntry], pages: [Page]) {
        self.meta = meta
        self.toc = toc
        self.pages = pages
    }
}

extension GenData {
    public func toJSON() throws -> String {
        try JSON.encode(self)
    }
}
