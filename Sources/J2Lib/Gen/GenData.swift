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

    public struct Def: Encodable {
        public let abstract: Localized<Html>?
        public let overview: Localized<Html>?
        public let swiftDeclaration: Html?
        public let returns: Localized<Html>?
        //        public let availability: [String]
    }
    public struct Item: Encodable {
        public let anchorId: String
        public let flatTitle: Localized<String>
        public let swiftTitleHtml: Html?
        public let dashType: String?
        public let url: URLPieces?
        // public let usageDiscouraged: Bool
        public let def: Def?

        /// Link init
        public init(anchorId: String, title: Localized<String>, url: URLPieces) {
            self.anchorId = anchorId
            self.flatTitle = title
            self.swiftTitleHtml = nil
            self.dashType = nil
            self.url = url
            self.def = nil
        }

        /// Full item init
        public init(anchorId: String,
                    flatTitle: Localized<String>,
                    swiftTitleHtml: Html,
                    dashType: String,
                    url: URLPieces?,
                    def: Def) {
            self.anchorId = anchorId
            self.flatTitle = flatTitle
            self.swiftTitleHtml = swiftTitleHtml
            self.dashType = dashType
            self.url = url
            self.def = def
        }
    }
    public struct Topic: Encodable {
        public let title: RichText
        public let anchorId: String
        public let body: Localized<Html>?
        public let items: [Item]
    }
    public struct Page: Encodable {
        public let url: URLPieces
        public let title: Localized<String>
        public let tabTitlePrefix: Bool
        public let isGuide: Bool
        public let content: Localized<Html>?
        // breadcrumbs
        public let def: Def?
        // topics
        public let topics: [Topic]

        /// Def init
        public init(defURL: URLPieces,
                    title: Localized<String>,
                    definition: Def,
                    topics: [Topic] = []) {
            self.url = defURL
            self.title = title
            self.tabTitlePrefix = true
            self.isGuide = false
            self.content = nil
            self.def = definition
            self.topics = topics
        }

        /// Group init
        public init(groupURL: URLPieces,
                    title: Localized<String>,
                    content: Localized<Html>?,
                    topics: [Topic] = []) {
            self.url = groupURL
            self.title = title
            self.tabTitlePrefix = true
            self.isGuide = false
            self.content = content
            self.def = nil
            self.topics = topics
        }

        /// Guide init
        public init(guideURL: URLPieces,
                    title: Localized<String>,
                    isReadme: Bool,
                    content: Localized<Html>?) {
            self.url = guideURL
            self.title = title
            self.tabTitlePrefix = !isReadme
            self.isGuide = true
            self.content = content
            self.def = nil
            self.topics = []
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
