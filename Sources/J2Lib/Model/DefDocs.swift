//
//  ItemDefMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Broken-down documentation for some definition in some format
public struct DefDocs<T>: Encodable where T: Encodable {
    public internal(set) var abstract: T?
    public internal(set) var overview: T?
    public internal(set) var returns: T?
    public internal(set) var parameters: [String: T]

    /// Initialize a new documentation container
    public init(abstract: T? = nil,
                overview: T? = nil,
                returns: T? = nil,
                parameters: [String : T] = [:]) {
        self.abstract = abstract
        self.overview = overview
        self.returns = returns
        self.parameters = parameters
    }

    /// Is there any content?
    public var isEmpty: Bool {
        abstract == nil &&
            overview == nil &&
            returns == nil &&
            parameters.isEmpty
    }
}

/// Def docs from one pass over the doc comment
public typealias FlatDefDocs = DefDocs<Markdown>

/// Def docs from one pass over the doc comment in each language
public typealias LocalizedDefDocs = DefDocs<Localized<Markdown>>

extension LocalizedDefDocs {
    /// Add a translation to the set.
    /// Whichever way I shake these data structures there's always one incredibly ugly piece.
    /// This is the least bad option I've found.
    public mutating func set(tag: String, docs: DefDocs<Markdown>) {
        if let tabstract = docs.abstract {
            var abstract = self.abstract ?? [:]
            abstract[tag] = tabstract
            self.abstract = abstract
        }
        if let toverview = docs.overview {
            var overview = self.overview ?? [:]
            overview[tag] = toverview
            self.overview = overview
        }
        if let treturns = docs.returns {
            var returns = self.returns ?? [:]
            returns[tag] = treturns
            self.returns = returns
        }
        docs.parameters.forEach { pk, pv in
            if var param = parameters[pk] {
                param[tag] = pv
                parameters[pk] = param
            } else {
                parameters[pk] = [tag: pv]
            }
        }
    }
}

/// Def docs ready for formatting / after formatting
public typealias RichDefDocs = DefDocs<RichText>

extension RichDefDocs {
    public init(_ ldocs: LocalizedDefDocs) {
        abstract = ldocs.abstract.flatMap { RichText($0) }
        overview = ldocs.overview.flatMap { RichText($0) }
        returns = ldocs.returns.flatMap { RichText($0) }
        parameters = ldocs.parameters.mapValues { RichText($0) }
    }

    public mutating func format(_ call: (Markdown) throws -> (Markdown, Html) ) rethrows {
        try abstract?.format(call)
        try overview?.format(call)
        try returns?.format(call)
        parameters = try parameters.mapValues { val in
            var rich = val
            try rich.format(call)
            return rich
        }
    }
}
