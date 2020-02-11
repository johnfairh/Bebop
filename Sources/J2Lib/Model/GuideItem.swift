//
//  GuideItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation


/// A pure markdown page in the docs rendered from a user configuration
public class GuideItem: Item {
    private(set) var markdownContent: Localized<Markdown>
    private(set) var htmlContent: Localized<Html>

    /// Create a new guide item.
    /// - parameter name: The name of the guide as described by the user, case-sensitive, any characters.
    ///                   Used for autolinking.
    /// - parameter slug: The uniqued filesystem-friendly name for the guide used in URL construction.
    /// - parameter title: The translated title of the guide, used in the navigation.
    /// - parameter content: The translated markdown for the guide, used to generate the guide itself.
    public init(name: String, slug: String, title: Localized<String>, content: Localized<Markdown>) {
        self.markdownContent = content
        self.htmlContent = Localized<Html>()
        super.init(name: name, slug: slug, title: title)
    }

    /// Visitor
    override func accept(visitor: ItemVisitor, parents: [Item]) {
        visitor.visit(guideItem: self, parents: parents)
    }

    override var kind: ItemKind { .guide }

    override var showInToc: ShowInToc { .yes }
}

/// Special override for the readme / index.html that has no real name except in the filesystem.
public final class ReadmeItem : GuideItem {
    private static let index = "index"

    public init(content: Localized<Markdown>) {
        super.init(name: ReadmeItem.index,
                   slug: ReadmeItem.index,
                   title: Localized<String>(unlocalized: ReadmeItem.index),
                   content: content)
    }

    /// Visitor
    override func accept(visitor: ItemVisitor, parents: [Item]) {
        visitor.visit(readmeItem: self, parents: parents)
    }

    override var showInToc: ShowInToc { .no }
}
