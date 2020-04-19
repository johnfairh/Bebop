//
//  FormatURL.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Collect the routines for assigning and working with URLs.

extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
    }

    var urlFragmentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
    }

    var removingPercentEncoding: String {
        removingPercentEncoding!
    }
}

public struct URLPieces: Encodable {
    /// %-encoded URL path, without file extension
    public let urlPath: String
    /// %-encoded URL hash, or `nil` if no hash
    public let urlHash: String?

    /// Initialize for a sequence of directories and a page name
    init(pathComponents: [String]) {
        urlPath = pathComponents.map { $0.urlPathEncoded }.joined(separator: "/")
        urlHash = nil
    }

    /// Initialize for a nested web page
    init(parentURL: URLPieces, pageName: String) {
        urlPath = parentURL.urlPath + "/" + pageName.urlPathEncoded
        urlHash = nil
    }

    /// Initialize for an anchor on a web page
    init(parentURL: URLPieces, hashName: String) {
        urlPath = parentURL.urlPath
        urlHash = hashName.urlFragmentEncoded
    }

    init() {
        urlPath = ""
        urlHash = nil
    }

    /// URL hash/fragment (for relative use on the same page)
    public var hashURL: String {
        urlHash.flatMap { "#\($0)" } ?? ""
    }

    /// Get the url (path + fragment/hash), assuming some file extension.  %-encoded for a URL.
    /// Add a language to force the version of the page for that language.
    public func url(fileExtension: String, language: DefLanguage? = nil) -> String {
        let query = language.flatMap { $0.urlQuery } ?? ""
        return urlPath + fileExtension + query + hashURL
    }

    /// Get the file-system name of the page, assuming some file extension.
    /// Invalid for hashes.
    public func filepath(fileExtension: String) -> String {
        precondition(urlHash == nil)
        return url(fileExtension: fileExtension).removingPercentEncoding
    }

    /// For Dash docset, the filesystem (unescaped) path with any fragment (presumably unescaped?)
    public var dashFilepath: String {
        "\(urlPath).html\(hashURL)"
    }

    /// Get a path from this item's page back up to the doc root - either empty string or ends in a slash
    public var pathToRoot: String {
        return String(repeating: "../", count: urlPath.directoryNestingDepth)
    }
}

extension Item {
    /// Set this item to be an absolutely positioned  page in docs
    func setURLPath(parentPaths: [String] = []) {
        url = URLPieces(pathComponents: parentPaths + [slug])
    }

    /// Set this item to be its own page in docs, nested under some parent page
    func setURLPath(parentURL: URLPieces) {
        url = URLPieces(parentURL: parentURL, pageName: slug)
    }

    /// Set this item to be embedded in some parent page
    func setURLHash(parentURL: URLPieces) {
        url = URLPieces(parentURL: parentURL, hashName: slug)
    }

    /// Does the item get its own page in the docs?  If not then it is inlined into its parent.
    var renderAsPage: Bool {
        url.urlHash == nil
    }
}

extension DefLanguage {
    /// Thing to include in a URL to force this language
    var urlQuery: String {
        switch self {
        case .swift: return "?swift"
        case .objc: return "?objc"
        }
    }
}

extension ChildItemStyle {
    /// Should we embed the item in its parent given the chance?  Means it has no page of its own.
    func shouldEmbed(defItem: DefItem) -> Bool {
        switch self {
        case .nested:
            // Embed if no children
            return defItem.children.isEmpty
        case .nested_separate_types:
            // Always create pages for nominal types even if no members
            return defItem.children.isEmpty && defItem.showInToc == .yes
        case .separate:
            // Never embed
            return false
        }
    }
}

struct URLFormatter: ItemVisitorProtocol {
    let childItemStyle: ChildItemStyle
    let multiModule: Bool

    func visit(defItem: DefItem, parents: [Item]) {
        guard let parent = parents.last else {
            preconditionFailure() // must be in a group at least
        }

        if childItemStyle.shouldEmbed(defItem: defItem) {
            // embed on parent page
            defItem.setURLHash(parentURL: parent.url)
        } else if parent.kind == .group {
            // a top-level def, place according to kind
            // NOT THE PARENT!  PARENT MAY BE A NESTED CUSTOM CATEGORY.
            if multiModule {
                defItem.setURLPath(parentPaths: [
                    defItem.location.moduleName.slugged,
                    defItem.defKind.metaKind.name.slugged])
            } else {
                defItem.setURLPath(parentPaths: [defItem.defKind.metaKind.name.slugged])
            }
        } else {
            // we're a nested def that does not embed, we go in our parent's directory
            defItem.setURLPath(parentURL: parent.url)
        }
    }

    /// Groups all go in the top level using their slug as a name.
    func visit(groupItem: GroupItem, parents: [Item]) {
        groupItem.setURLPath()
    }

    /// Guides in the guides directory.
    func visit(guideItem: GuideItem, parents: [Item]) {
        guideItem.setURLPath(parentPaths: [ItemKind.guide.name.slugged])
    }

    /// Readme at the top
    func visit(readmeItem: ReadmeItem, parents: [Item]) {
        readmeItem.setURLPath()
    }
}
