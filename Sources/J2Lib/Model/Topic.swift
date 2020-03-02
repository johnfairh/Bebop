//
//  Topic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Topic: Equatable, Encodable {
    public internal(set) var title: RichText
    public internal(set) var body: RichText?

    /// Initialize from a pragma/MARK in source code or static string (will be treated as markdown)
    public init(title: String = "") {
        self.title = RichText(title)
        self.body = nil
    }

    /// Initialize from a custom topic definition
    public init(title: Localized<Markdown>, body: Localized<Markdown>?) {
        self.title = RichText(title)
        self.body = body.flatMap { RichText($0) }
    }

    /// Format the topic's content
    public func format(_ formatter: RichText.Formatter) rethrows {
        try title.format(formatter)
        try body?.format(formatter)
    }

    /// Not sure what stops this from being auto-generated.
    public static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.title == rhs.title &&
            lhs.body == rhs.body
    }
}

// TopicKind
// - SourceMark
// - GenericConstraint
// - CategoryName
// - Custom
// - DefKind
