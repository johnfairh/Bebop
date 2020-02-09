//
//  DocsData.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// A somewhat-normalized pure-ish data structure containing everything
/// required to render the site.
///
/// Dumped for the `docs-summary-json` product.
public struct DocsData: Encodable {
    public struct Meta: Encodable {
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
        // breadcrumbs
        public let swiftDeclaration: String
        public let availability: [String]
        public let abstract: Localized<Html>
        public let overview: Localized<Html>
        // topics
    }
    public let pages: [Page]
}

extension DocsData {
    public func toJSON() throws -> String {
        try JSON.encode(self)
    }
}
