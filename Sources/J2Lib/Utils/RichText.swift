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
        case .unformatted(_): preconditionFailure() // ???
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
