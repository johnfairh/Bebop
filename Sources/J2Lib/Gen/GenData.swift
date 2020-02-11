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
        /// Modules being documented
        public let moduleNames: Set<String>
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
        public let isGuide: Bool
        // breadcrumbs
//        public let swiftDeclaration: String
//        public let availability: [String]
//        public let abstract: Localized<Html>
//        public let overview: Localized<Html>
        // topics
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
