//
//  DocsData.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// A somewhat-normalized pure-ish data structure containing everything
/// required to render the parts of the site that change page-to-page.
///
/// Dumped for the `docs-summary-json` product.
public final class GenData: Encodable {
    public struct Meta: Encodable {
        /// Version of this program
        public let version: String
        /// Languages supported
        public let languages: [DefLanguage]
        /// Default language
        public let defaultLanguage: DefLanguage
    }
    public let meta: Meta
    public struct TocEntry: Encodable {
        public let url : URLPieces
        public let title: Localized<String>
        public let children: [TocEntry]
    }
    // match meta.languages
    public let tocs: [[TocEntry]]

    public struct Param: Encodable {
        public let name: String
        public let description: RichText
    }
    public struct Def: Encodable {
        public let deprecation: RichText?
        public let deprecatedEverywhere: Bool
        public let unavailability: RichText?
        public let notes: RichText?
        public let availability: [String]
        public let abstract: RichText?
        public let discussion: RichText?
        public let defaultAbstract: RichText?
        public let defaultDiscussion: RichText?
        public let swiftDeclaration: RichDeclaration?
        public let objCDeclaration: RichDeclaration?
        public let params: [Param]
        public let `throws`: RichText?
        public let returns: RichText?
        public let codeHostURL: String?
    }
    public struct Item: Encodable {
        public let anchorId: String
        public let flatTitle: Localized<String>
        public let primaryLanguage: DefLanguage
        public let secondaryLanguage: DefLanguage?
        public let primaryTitleHtml: Html?
        public let secondaryTitleHtml: Html?
        public let extensionConstraint: Localized<String>?
        public let dashType: String?
        public let url: URLPieces?
        public let def: Def?

        /// Link init
        init(anchorId: String, title: Localized<String>, url: URLPieces) {
            self.anchorId = anchorId
            self.flatTitle = title
            self.primaryLanguage = .swift
            self.secondaryLanguage = nil
            self.primaryTitleHtml = nil
            self.secondaryTitleHtml = nil
            self.extensionConstraint = nil
            self.dashType = nil
            self.url = url
            self.def = nil
        }

        /// Full item init
        init(anchorId: String,
             flatTitle: Localized<String>,
             primaryLanguage: DefLanguage,
             secondaryLanguage: DefLanguage?,
             primaryTitleHtml: Html?,
             secondaryTitleHtml: Html?,
             extensionConstraint: Localized<String>?,
             dashType: String,
             url: URLPieces?,
             def: Def) {
            self.anchorId = anchorId
            self.flatTitle = flatTitle
            self.primaryLanguage = primaryLanguage
            self.secondaryLanguage = secondaryLanguage
            self.primaryTitleHtml = primaryTitleHtml
            self.secondaryTitleHtml = secondaryTitleHtml
            self.extensionConstraint = extensionConstraint
            self.dashType = dashType
            self.url = url
            self.def = def
        }
    }
    public struct Topic: Encodable {
        public let title: RichText
        public let menuTitle: Localized<String>
        public let anchorId: String
        public let overview: RichText?
        public let items: [Item]
    }
    public struct GuideTopic: Encodable {
        public let title: String
        public let anchorId: String
    }
    public struct Breadcrumb: Encodable {
        public let title: Localized<String>
        public let url: URLPieces?
    }
    public struct PaginationLink: Encodable {
        public let url: URLPieces
        public let primaryTitle: Localized<String>
        public let secondaryTitle: Localized<String>
        public let primaryLanguage: DefLanguage
        public let secondaryLanguage: DefLanguage
    }
    public struct Pagination: Encodable {
        public let prev: PaginationLink?
        public let next: PaginationLink?
    }
    public struct Page: Encodable {
        public let url: URLPieces
        public let tocActiveURL: URLPieces?
        public let primaryTitle: Localized<String>
        public let primaryLanguage: DefLanguage
        public let secondaryTitle: Localized<String>?
        public let tabTitlePrefix: Bool
        public let isGuide: Bool
        public let mixLanguages: Bool
        public let content: RichText?
        // goes with meta.languages
        public let breadcrumbs: [[Breadcrumb]]
        public let def: Def?
        public let topics: [Topic]
        public let guideTopics: Localized<[GuideTopic]>
        public let pagination: Pagination
        public let codeHostURL: Localized<String>?

        /// Def init
        init(defURL: URLPieces,
             tocActiveURL: URLPieces?,
             primaryTitle: Localized<String>,
             primaryLanguage: DefLanguage,
             secondaryTitle: Localized<String>?,
             breadcrumbs: [[Breadcrumb]],
             definition: Def,
             topics: [Topic],
             pagination: Pagination,
             codeHostURL: Localized<String>?) {
            self.url = defURL
            self.tocActiveURL = tocActiveURL
            self.primaryTitle = primaryTitle
            self.primaryLanguage = primaryLanguage
            self.secondaryTitle = secondaryTitle
            self.tabTitlePrefix = true
            self.isGuide = false
            self.mixLanguages = false
            self.content = nil
            self.breadcrumbs = breadcrumbs
            self.def = definition
            self.topics = topics
            self.guideTopics = [:]
            self.pagination = pagination
            self.codeHostURL = codeHostURL
        }

        /// Group init
        init(groupURL: URLPieces,
             primaryTitle: Localized<String>,
             primaryLanguage: DefLanguage,
             secondaryTitle: Localized<String>?,
             breadcrumbs: [[Breadcrumb]],
             mixLanguages: Bool,
             content: RichText?,
             topics: [Topic],
             pagination: Pagination,
             codeHostURL: Localized<String>?) {
            self.url = groupURL
            self.tocActiveURL = nil
            self.primaryTitle = primaryTitle
            self.primaryLanguage = primaryLanguage
            self.secondaryTitle = secondaryTitle
            self.tabTitlePrefix = true
            self.isGuide = false
            self.mixLanguages = mixLanguages
            self.content = content
            self.breadcrumbs = breadcrumbs
            self.def = nil
            self.topics = topics
            self.guideTopics = [:]
            self.pagination = pagination
            self.codeHostURL = codeHostURL
        }

        /// Guide init
        init(guideURL: URLPieces,
             title: Localized<String>,
             breadcrumbs: [[Breadcrumb]],
             isReadme: Bool,
             content: RichText?,
             topics: Localized<[GuideTopic]>,
             pagination: Pagination,
             codeHostURL: Localized<String>?) {
            self.url = guideURL
            self.tocActiveURL = nil
            self.primaryTitle = title
            self.primaryLanguage = .swift
            self.secondaryTitle = nil
            self.tabTitlePrefix = !isReadme
            self.isGuide = true
            self.mixLanguages = false
            self.content = content
            self.breadcrumbs = breadcrumbs
            self.def = nil
            self.topics = []
            self.guideTopics = topics
            self.pagination = pagination
            self.codeHostURL = codeHostURL
        }
    }
    public let pages: [Page]

    init(meta: Meta, tocs: [[TocEntry]], pages: [Page]) {
        self.meta = meta
        self.tocs = tocs
        self.pages = pages
    }
}

extension GenData {
    public func toJSON() throws -> String {
        try JSON.encode(self)
    }
}
