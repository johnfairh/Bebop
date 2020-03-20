//
//  RichText.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Strongly-typed wrapper for markdown documents
public struct Markdown: CustomStringConvertible, Hashable, Encodable {
    public let md: String

    public init(_ md: String) {
        self.md = md
    }

    public var description: String {
        md
    }

    public static func +(lhs: Self, rhs: Self) -> Self {
        Markdown(lhs.md + rhs.md)
    }

    public static func +(lhs: Self, rhs: String) -> Self {
        Markdown(lhs.md + rhs)
    }
}

/// Strongly-typed wrapper for html
public struct Html: CustomStringConvertible, Hashable, Encodable {
    public let html: String

    public init(_ html: String) {
        self.html = html
    }

    public var description: String {
        html
    }

    public static func +(lhs: Self, rhs: Self) -> Self {
        Html(lhs.html + rhs.html)
    }

    public static func +(lhs: Self, rhs: String) -> Self {
        Html(lhs.html + rhs)
    }
}

import func Mustache.escapeHTML
extension String {
    var htmlEscaped: String {
        Mustache.escapeHTML(self)
    }
}

/// Some text manipulated by the program.
/// Localized and formattable.
public enum RichText: Encodable, Equatable {
    /// Localized markdown from a source file
    case unformatted(Localized<Markdown>)
    /// Formatted version of the markdown (autolinks inserted) and the HTML version
    case formatted(Localized<Markdown>, Localized<Html>)

    /// Initialize from a string, presumed to be markdown, used for all localizations
    public init(_ text: String) {
        self = .unformatted(.init(unlocalized: Markdown(text)))
    }

    /// Initialize from some markdown, used for all localizations
    public init(_ markdown: Markdown) {
        self = .unformatted(.init(unlocalized: markdown))
    }

    /// Initialize from some localized markdown
    public init(_ localizedMarkdown: Localized<Markdown>) {
        self = .unformatted(localizedMarkdown)
    }

    /// Initialize from some mistyped localized markdown
    public init(_ localizedText: Localized<String>) {
        self = .unformatted(localizedText.mapValues { Markdown($0) })
    }

    /// Get the markdown
    public var markdown: Localized<Markdown> {
        switch self {
        case .unformatted(let md): return md
        case .formatted(let md, _): return md
        }
    }

    /// Get the html - must only call if formatted
    public var html: Localized<Html> {
        switch self {
        case .unformatted(_): preconditionFailure()
        case .formatted(_, let html): return html
        }
    }

    /// Something that knows how to convert Markdown to HTML
    public typealias Formatter = (Markdown) throws -> (Markdown, Html)

    /// Format the text
    mutating public func format(_ formatter: Formatter) rethrows {
        switch self {
        case .formatted(_,_): return
        case .unformatted(let locMd):
            let formatted = try locMd.mapValues { try formatter($0) }
            self = .formatted(formatted.mapValues { $0.0 }, formatted.mapValues { $0.1 })
        }
    }

    // MARK: Encodable

    private enum CodingKeys: CodingKey {
        case markdown
        case html
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unformatted(let md):
            try container.encode(md.mapValues { $0.md }, forKey: .markdown)
        case .formatted(let md, let html):
            try container.encode(md.mapValues { $0.md }, forKey: .markdown)
            try container.encode(html.mapValues { $0.html }, forKey: .html)
        }
    }
}

import Maaku

extension RichText {
    public var plainText: Localized<String> {
        markdown.mapValues { md in
            guard let doc = CMDocument(markdown: md) else {
                return md.md
            }
            return doc.node.renderPlainText()
        }
    }
}

/// Wrap up declarations and their formatting behaviour.
///
/// Declarations are different: not localized, fixed line format, and we need
/// to output html directly containing autolinks.
public enum RichDeclaration: Encodable, Comparable {
    /// Unformatted version of the declaration
    case unformatted(String)
    /// Formatted version of the declaration
    case formatted(String, Html)

    public init(_ declaration: String) {
        self = .unformatted(declaration)
    }

    /// Get the plain text
    public var text: String {
        switch self {
        case .unformatted(let text): return text
        case .formatted(let text, _): return text
        }
    }

    /// Get the html - must only call if formatted
    public var html: Html {
        switch self {
        case .unformatted(_): preconditionFailure()
        case .formatted(_, let html): return html
        }
    }

    /// Something that knows how to convert declaration text to HTML
    public typealias Formatter = (String) throws -> Html

    /// Format the declaration
    mutating public func format(_ formatter: Formatter) rethrows {
        switch self {
        case .formatted(_,_): return
        case .unformatted(let text):
            self = .formatted(text, try formatter(text))
        }
    }

    // MARK: Encodable
    private enum CodingKeys: CodingKey {
        case text
        case html
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unformatted(let text):
            try container.encode(text, forKey: .text)
        case .formatted(let text, let html):
            try container.encode(text, forKey: .text)
            try container.encode(html, forKey: .html)
        }
    }

    /// Order by plaintext
    public static func < (lhs: RichDeclaration, rhs: RichDeclaration) -> Bool {
        lhs.text < rhs.text
    }
}
