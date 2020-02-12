//
//  Topic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Topic: Encodable {
    public internal(set) var title: RichText
    public internal(set) var body: RichText?

    /// Initialize from a pragma/MARK in source code or static string
    public init(title: String) {
        self.title = RichText(title)
        self.body = nil
    }

    /// Initialize from a custom topic definition
    public init(title: Localized<Markdown>, body: Localized<Markdown>?) {
        self.title = RichText(title)
        self.body = body.flatMap { RichText($0) }
    }
}
