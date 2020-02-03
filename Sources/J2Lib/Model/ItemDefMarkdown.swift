//
//  ItemDefMarkdown.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

public struct Markdown: CustomStringConvertible, Hashable {
    public let md: String

    public init(_ md: String) {
        self.md = md
    }

    public var description: String {
        md
    }
}

public struct DefDocumentation<T: CustomStringConvertible> {
    public let abstract: T?
    public let overview: T?
    public let returns: T?
    public let parameters: [String: T]
}

public typealias DefMarkdown = DefDocumentation<Markdown>

extension DefDocumentation: Encodable {
    fileprivate enum CodingKeys: String, CodingKey {
        case abstract
        case overview
        case returns
        case parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(abstract?.description, forKey: .abstract)
        try container.encode(overview?.description, forKey: .overview)
        try container.encode(parameters.mapValues { $0.description}, forKey: .parameters)
    }
}
