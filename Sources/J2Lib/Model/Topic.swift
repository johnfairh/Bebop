//
//  Topic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Topic: Equatable, Encodable {
    public private(set) var title: RichText
    public private(set) var _menuTitle: RichText?
    public private(set) var body: RichText?
    public private(set) var kind: TopicKind

    public var menuTitle: RichText {
        _menuTitle ?? title
    }

    /// Initialize from a pragma/MARK in source code or static string (will be treated as markdown)
    public init(title: String = "") {
        self.title = RichText(title)
        self.body = nil
        self.kind = .sourceMark
    }

    /// Initialize from a custom topic definition
    public init(title: Localized<Markdown>, body: Localized<Markdown>?) {
        self.title = RichText(title)
        self.body = body.flatMap { RichText($0) }
        self.kind = .custom
    }

    /// Initialize for an ObjC Category
    public init(categoryName: ObjCCategoryName) {
        self.title = RichText(categoryName.categoryName)
        self.body = nil
        self.kind = .category
    }

    /// Initialize from some generic constraints
    public init(requirements: String) {
        let markdown = requirements.re_sub(#"[\w\.]+"#, with: #"`$0`"#)
        self.title = RichText(.localizedOutput(.availableWhere, markdown))
        self._menuTitle = RichText(.localizedOutput(.availableWhereShort, markdown))
        self.body = nil
        self.kind = .genericRequirements
    }

    /// Make a user mark to a generic requirements marker
    public func makeGenericRequirement() {
        kind = .genericRequirements
    }

    /// Format the topic's content
    public func format(_ formatter: RichText.Formatter) rethrows {
        try title.format(formatter)
        try _menuTitle?.format(formatter)
        try body?.format(formatter)
    }

    /// Not sure what stops this from being auto-generated.
    public static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.title == rhs.title &&
            lhs.body == rhs.body
    }
}

public enum TopicKind: String, Equatable, Encodable {
    case sourceMark
    case category
    case genericRequirements
    case custom
    case defKind
}
