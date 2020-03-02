//
//  ItemDefMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Broken-down documentation for some definition in some format
public struct DefDocs<T>: Encodable where T: Encodable & Equatable {
    public internal(set) var abstract: T?
    public internal(set) var discussion: T?
    public internal(set) var defaultAbstract: T?
    public internal(set) var defaultDiscussion: T?
    public internal(set) var returns: T?
    public struct Param: Encodable, Equatable {
        public let name: String
        public internal(set) var description: T
    }
    public internal(set) var parameters: [Param]

    /// Initialize a new documentation container
    public init(abstract: T? = nil,
                discussion: T? = nil,
                defaultAbstract: T? = nil,
                defaultDiscussion: T? = nil,
                returns: T? = nil,
                parameters: [Param] = []) {
        self.abstract = abstract
        self.discussion = discussion
        self.defaultAbstract = defaultAbstract
        self.defaultDiscussion = defaultDiscussion
        self.returns = returns
        self.parameters = parameters
    }

    /// Is there any content?
    public var isEmpty: Bool {
        abstract == nil &&
            discussion == nil &&
            defaultAbstract == nil &&
            defaultDiscussion == nil &&
            returns == nil &&
            parameters.isEmpty
    }

    /// Move abstract & discussion to defaults leaving them blank
    public mutating func makeDefaultImplementation() {
        setDefaultImplementation(from: self)
        self.abstract = nil
        self.discussion = nil
    }

    /// Set default abstract/discussion from another docs' primary fields
    public mutating func setDefaultImplementation(from: Self) {
        self.defaultAbstract = from.abstract
        self.defaultDiscussion = from.discussion
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
    public mutating func set(tag: String, docs: FlatDefDocs) {
        func s(mdKeyPath: KeyPath<FlatDefDocs, Markdown?>,
               locKeyPath: WritableKeyPath<Self, Localized<Markdown>?>) {
            if let thing = docs[keyPath: mdKeyPath] {
                var current = self[keyPath: locKeyPath] ?? [:]
                current[tag] = thing
                self[keyPath: locKeyPath] = current
            }
        }
        s(mdKeyPath: \.abstract, locKeyPath: \.abstract)
        s(mdKeyPath: \.discussion, locKeyPath: \.discussion)
        s(mdKeyPath: \.defaultAbstract, locKeyPath: \.defaultAbstract)
        s(mdKeyPath: \.defaultDiscussion, locKeyPath: \.defaultDiscussion)
        s(mdKeyPath: \.returns, locKeyPath: \.returns)

        if parameters.isEmpty {
            parameters = docs.parameters.map {
                Param(name: $0.name, description: [tag: $0.description])
            }
        } else {
            parameters = parameters.map { currParam in
                for newParam in docs.parameters {
                    if newParam.name == currParam.name {
                        var currParam = currParam
                        currParam.description[tag] = newParam.description
                        return currParam
                    }
                }
                // Ignores newly introduced params...
                return currParam
            }
        }
    }
}

/// Def docs ready for formatting / after formatting
public typealias RichDefDocs = DefDocs<RichText>

extension RichDefDocs {
    public init(_ ldocs: LocalizedDefDocs) {
        abstract = ldocs.abstract.flatMap { RichText($0) }
        discussion = ldocs.discussion.flatMap { RichText($0) }
        defaultAbstract = ldocs.defaultAbstract.flatMap { RichText($0) }
        defaultDiscussion = ldocs.defaultDiscussion.flatMap { RichText($0) }
        returns = ldocs.returns.flatMap { RichText($0) }
        parameters = ldocs.parameters.map {
            Param(name: $0.name, description: RichText($0.description))
        }
    }

    public mutating func format(_ call: (Markdown) throws -> (Markdown, Html) ) rethrows {
        try abstract?.format(call)
        try discussion?.format(call)
        try defaultAbstract?.format(call)
        try defaultDiscussion?.format(call)
        try returns?.format(call)
        parameters = try parameters.map { param in
            var param = param
            try param.description.format(call)
            return param
        }
    }
}
