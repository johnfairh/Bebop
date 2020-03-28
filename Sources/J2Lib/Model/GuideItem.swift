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
    public private(set) var content: RichText
    public let title: Localized<String>

    /// Create a new guide item.
    /// - parameter name: The name of the guide as described by the user, case-sensitive, any characters.
    ///                   Used for autolinking.
    /// - parameter slug: The uniqued filesystem-friendly name for the guide used in URL construction.
    /// - parameter title: The translated title of the guide, used in the navigation.
    /// - parameter content: The translated markdown for the guide, used to generate the guide itself.
    init(name: String, slug: String, title: Localized<String>, content: Localized<Markdown>) {
        self.content = RichText(content)
        self.title = title
        super.init(name: name, slug: slug)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) {
        visitor.visit(guideItem: self, parents: parents)
    }

    public override var kind: ItemKind { .guide }

    public override func title(for language: DefLanguage) -> Localized<String>? {
        return title
    }

    public override var showInToc: ShowInToc { .yes }

    override func format(formatters: RichText.Formatters) {
        content.format(formatters.block)
    }
}

/// Special override for the readme / index.html that has no real name except in the filesystem.
public final class ReadmeItem : GuideItem {
    private static let index = "index"

    init(content: Localized<Markdown>) {
        super.init(name: ReadmeItem.index,
                   slug: ReadmeItem.index,
                   title: Localized<String>(unlocalized: ReadmeItem.index),
                   content: content)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) {
        visitor.visit(readmeItem: self, parents: parents)
    }

    public override var showInToc: ShowInToc { .no }
}
