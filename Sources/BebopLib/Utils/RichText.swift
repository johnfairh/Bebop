//
//  RichText.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// Strongly-typed wrapper for string types

public enum StringKind {
    public enum Html {}
    public enum Markdown {}
}

public protocol BoxedStringProtocol {
    var value: String { get }
    init(_ value: String)
}

public struct BoxedString<P>: BoxedStringProtocol, CustomStringConvertible, Hashable, Encodable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public var description: String {
        value
    }

    public static func +(lhs: Self, rhs: Self) -> Self {
        Self(lhs.value + rhs.value)
    }

    public static func +(lhs: Self, rhs: String) -> Self {
        Self(lhs.value + rhs)
    }
}

public typealias Markdown = BoxedString<StringKind.Markdown>
public typealias Html = BoxedString<StringKind.Html>

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
    init(_ text: String) {
        self = .unformatted(.init(unlocalized: Markdown(text)))
    }

    /// Initialize from some markdown, used for all localizations
    init(_ markdown: Markdown) {
        self = .unformatted(.init(unlocalized: markdown))
    }

    /// Initialize from some localized markdown
    init(_ localizedMarkdown: Localized<Markdown>) {
        self = .unformatted(localizedMarkdown)
    }

    /// Initialize from some mistyped localized markdown
    init(_ localizedText: Localized<String>) {
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

    /// Something that knows how to convert Markdown in some localization to HTML
    typealias Formatter = (Markdown, String) -> (Markdown, Html)

    struct Formatters {
        public let inline: Formatter
        public let block: Formatter
    }

    /// Format the text
    mutating func format(_ formatter: Formatter) {
        switch self {
        case .formatted(_,_): return
        case .unformatted(let locMd):
            let formatted = locMd.map { ($0.key, formatter($0.value, $0.key)) }
            let formattedMd = Localized<Markdown>(uniqueKeysWithValues: formatted.map { ($0.0, $0.1.0) })
            let formattedHtml = Localized<Html>(uniqueKeysWithValues: formatted.map { ($0.0, $0.1.1) })
            self = .formatted(formattedMd, formattedHtml)
        }
    }

    /// Format the text as a paragraph list - changes the markdown side too
    mutating func formatAsParagraphList(_ formatter: Formatter) {
        switch self {
        case .formatted(_,_): return
        case .unformatted(_):
            format(formatter)
            if case let .formatted(md, html) = self {
                self = .formatted(CMDocument.parasToList(text: md), html)
            }
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
            try container.encode(md.mapValues { $0.value }, forKey: .markdown)
        case .formatted(let md, let html):
            try container.encode(md.mapValues { $0.value }, forKey: .markdown)
            try container.encode(html.mapValues { $0.value }, forKey: .html)
        }
    }
}

import Maaku

extension RichText {
    public var plainText: Localized<String> {
        markdown.mapValues { md in
            guard let doc = CMDocument(markdown: md) else {
                return md.value
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

    init(_ declaration: String) {
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
    typealias Formatter = (String, DefLanguage) throws -> Html

    /// Format the declaration
    mutating func format(_ formatter: Formatter, language: DefLanguage) rethrows {
        switch self {
        case .formatted(_,_): return
        case .unformatted(let text):
            self = .formatted(text, try formatter(text, language))
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
