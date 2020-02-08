//
//  FormatURL.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Collect the routines for assigning and working with URLs.

extension Item {
    /// Set this item to be its own page in docs, nested under some parent page
    func setURLPath(parentURLPath: String) {
        urlPath = parentURLPath + "/" + slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        urlHash = nil
    }

    /// Set this item to be embedded in some parent page
    func setURLHash(parentURLPath: String) {
        urlPath = parentURLPath
        urlHash = slug.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
    }

    /// Get the url (path + fragment/hash) for the item, assuming some file extension.  %-encoded for a URL.
    func url(fileExtension: String) -> String {
        let path = urlPath + fileExtension
        return urlHash.flatMap { path + "#\($0)" } ?? path
    }

    /// Get the file-system name of the item's page, assuming some file extension.
    /// Only valid for items that actually have their own page.
    func filepath(fileExtension: String) -> String {
        precondition(renderAsPage)
        return url(fileExtension: fileExtension).removingPercentEncoding!
    }

    /// Does the item get its own page in the docs?  If not then it is inlined into its parent.
    var renderAsPage: Bool {
        urlHash == nil
    }
}

struct URLVisitor: ItemVisitor {
    func visit(defItem: DefItem, parents: [Item]) {
        guard let parent = parents.last else {
            preconditionFailure() // must be in a group at least
        }

        if parent.kind == .group {
            // a top-level def, place according to kind
            // XXX need to understand multi-module here
            defItem.setURLPath(parentURLPath: defItem.defKind.metaKind.name)
        } else if !defItem.children.isEmpty {
            // we're a nested def with children, we go in our parent's directory
            defItem.setURLPath(parentURLPath: parent.urlPath)
        } else {
            // embed on parent page
            defItem.setURLHash(parentURLPath: parent.urlPath)
        }
    }

    /// Groups all go in the top level using their slug as a name.
    func visit(groupItem: GroupItem, parents: [Item]) {
        groupItem.urlPath = groupItem.slug
    }
}
