//
//  ItemDefMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Broken-down documentation for some definition in some format
public struct DefDocs<T: CustomStringConvertible> {
    public let abstract: T?
    public let overview: T?
    public let returns: T?
    public let parameters: [String: T]

    /// Initialize a new documentation container
    public init(abstract: T? = nil, overview: T? = nil, returns: T? = nil, parameters: [String:T] = [:]) {
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

/// Serialization for def documentation
extension DefDocs: Encodable {
    private enum CodingKeys: String, CodingKey {
        case abstract
        case overview
        case returns
        case parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(abstract?.description, forKey: .abstract)
        try container.encode(overview?.description, forKey: .overview)
        try container.encode(returns?.description, forKey: .returns)
        try container.encode(parameters.mapValues { $0.description}, forKey: .parameters)
    }
}

/// Def documentation encoded in markdown
public typealias DefMarkdownDocs = DefDocs<Markdown>

public typealias DefHtmlDocs = DefDocs<Html>
