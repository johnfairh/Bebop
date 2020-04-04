//
//  GatherSymbolGraph.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SortedArray
import SourceKittenFramework

// MARK: API

// namespace
enum GatherSymbolGraph {
    static func decode(data: Data, extensionModuleName: String) throws -> SourceKittenDict {
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)
        return graph.rebuild()
    }
}

// MARK: Network Model

/// Honest representation of the JSON with stuff we don't want omitted.
/// About as fragile as hard-coding keys I suppose.
fileprivate struct NetworkSymbolGraph: Decodable {
    struct Metadata: Decodable {
        let generator: String
    }
    let metadata: Metadata

    struct Constraint: Decodable {
        let kind: String
        let lhs: String
        let rhs: String
    }

    struct Symbol: Decodable {
        struct Kind: Decodable {
            let identifier: String
        }
        let kind: Kind
        struct Identifier: Decodable {
            let precise: String
        }
        let identifier: Identifier
        let pathComponents: [String]
        struct Names: Decodable {
            let title: String
        }
        let names: Names
        struct DocCommentLines: Decodable {
            struct DocCommentLine: Decodable {
                let text: String
            }
            let lines: [DocCommentLine]
        }
        let docComment: DocCommentLines?
        struct DeclFrag: Decodable {
            let spelling: String
        }
        struct Generics: Decodable {
            struct Parameter: Decodable {
                let name: String
                let depth: Int
            }
            let parameters: [Parameter]?
            let constraints: [Constraint]?
        }
        let swiftGenerics: Generics?
        let declarationFragments: [DeclFrag]
        let accessLevel: String
        struct Availability: Decodable {
            let domain: String?
            struct Version: Decodable {
                let major: Int
                let minor: Int?
                let patch: Int?
            }
            let introduced: Version?
            let deprecated: Version?
            let obsoleted: Version?
            let message: String?
            let renamed: String?
            let isUnconditionallyDeprecated: Bool?
        }
        let availability: [Availability]?
        struct Location: Decodable {
            let uri: String
            var file: String {
                URL(string: uri)?.path ?? uri
            }
            struct Position: Decodable {
                let line: Int
                let character: Int
            }
            let position: Position
        }
        let location: Location?
    }
    let symbols: [Symbol]
    struct Rel: Decodable {
        let kind: String
        let source: String
        let target: String
        let targetFallback: String?
        let swiftConstraints: [Constraint]?
    }
    let relationships: [Rel]
}

// MARK: Decoder

/// Flattened and more normally-named deserialized symbolgraph - all decoding of json happens here.
fileprivate struct SymbolGraph: Decodable {
    let generator: String

    struct Constraint: Comparable {
        enum Kind: String {
            case conformance
            case superclass
            case sameType

            var swift: String {
                switch self {
                case .conformance: return ":"
                case .superclass: return ":"
                case .sameType: return "=="
                }
            }
        }
        let text: String

        init?(_ c: NetworkSymbolGraph.Constraint) {
            guard let kind = Kind(rawValue: c.kind) else {
                return nil
            }
            text = "\(c.lhs) \(kind.swift) \(c.rhs)"
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.text < rhs.text
        }
    }

    struct Symbol: Equatable {
        let kind: String
        let usr: String
        let name: String
        let docComment: String?
        let declaration: String
        let accessLevel: String
        let availability: [String]
        struct Location: Equatable {
            let filename: String
            let line: Int
            let character: Int
        }
        let location: Location?
        let genericParameters: [String]
        let genericConstraints: SortedArray<Constraint>
    }
    let symbols: [Symbol]

    struct Rel {
        enum Kind: String {
            case memberOf
            case conformsTo
            case defaultImplementationOf
            case overrides
            case inheritsFrom
            case requirementOf
            case optionalRequirementOf
        }
        let kind: Kind
        let sourceUSR: String
        let targetUSR: String
        let targetFallback: String?
        let constraints: SortedArray<Constraint>
    }
    let rels: [Rel]

    init(from decoder: Decoder) throws {
        let network = try NetworkSymbolGraph(from: decoder)
        generator = network.metadata.generator

        // Symbols
        symbols = network.symbols.compactMap { sym in
            let declaration = Self.fixUpDeclaration(sym.declarationFragments.map { $0.spelling }.joined())
            guard let kind = Self.mapKind(sym.kind.identifier, declaration: declaration) else {
                logWarning("Unknown swift-symbolgraph symbol kind '\(sym.kind.identifier)', ignoring.")
                return nil
            }
            guard let acl = DefAcl(rawValue: sym.accessLevel)?.sourceKitName else {
                logWarning("Unknown swift-symbolgraph access level '\(sym.accessLevel)', ignoring.")
                return nil
            }
            let location = sym.location.flatMap {
                Symbol.Location(filename: $0.file, line: $0.position.line, character: $0.position.character)
            }
            let constraints = sym.swiftGenerics?.constraints?.compactMap { con -> Constraint? in
                // Drop implementation Self constraint for protocol members
                if con.lhs == "Self" && con.kind == "conformance" && sym.pathComponents.contains(con.rhs) {
                    return nil
                }
                return Constraint(con)
            } ?? []
            return Symbol(kind: kind,
                          usr: sym.identifier.precise,
                          name: sym.names.title,
                          docComment: sym.docComment?.lines.map { $0.text }.joined(separator: "\n"),
                          declaration: declaration,
                          accessLevel: acl,
                          availability: sym.availability?.compactMap { $0.asSwift } ?? [],
                          location: location,
                          genericParameters: sym.swiftGenerics?.parameters?.map { $0.name } ?? [],
                          genericConstraints: SortedArray(unsorted: constraints))
        }

        // Relationships
        rels = network.relationships.compactMap { rel in
            guard let kind = Rel.Kind(rawValue: rel.kind) else {
                logWarning("Unknown swift-symbolgraph relationship kind '\(rel.kind)', ignoring.")
                return nil
            }
            let constraints = rel.swiftConstraints?.compactMap(Constraint.init) ?? []
            return Rel(kind: kind,
                       sourceUSR: rel.source,
                       targetUSR: rel.target,
                       targetFallback: rel.targetFallback,
                       constraints: SortedArray(unsorted: constraints))
        }
    }
}

// MARK: @available

extension NetworkSymbolGraph.Symbol.Availability {
    /// Reconstitute the "@available" statement so that we can push it through SwiftSyntax.  Good game, good game.
    var asSwift: String? {
        var str = "@available("

        if let domain = domain {
            str += "\(domain)"
            [("introduced", \Self.introduced),
             ("deprecated", \Self.deprecated),
             ("obsoleted", \Self.obsoleted)].forEach { name, kp in
                if let version = self[keyPath: kp] {
                    str += ", \(name): \(version.asSwift)"
                }
            }
        } else if isUnconditionallyDeprecated != nil {
            str += "*, deprecated"
        } else {
            logWarning("Found swift-symbolgraph 'availability' missing both domain and isUnconditionallyDeprecated")
            return nil
        }

        if let message = message {
            str += ", message: \"\(message)\""
        }
        if let renamed = renamed {
            str += ", renamed: \"\(renamed)\""
        }
        str += ")"
        return str
    }
}

extension NetworkSymbolGraph.Symbol.Availability.Version {
    var asSwift: String {
        var str = String(major)
        if let minor = minor {
            str += ".\(minor)"
            if let patch = patch {
                str += ".\(patch)"
            }
        }
        return str
    }
}


// MARK: Declaration Fixup

extension SymbolGraph {
    /// Work around bugs/bad design in ssge's declprinter
    static func fixUpDeclaration(_ declaration: String) -> String {
        declaration
            // All these Selfs are pointless & I don't want to teach autolink about them
            .re_sub(#"\bSelf."#, with: "")
            // Try to fix up `func(_: Int)` stuff
            .re_sub(#"(?<=\(|, )_: "#, with: "_ arg: ")
    }
}

// MARK: Declaration Kinds

extension SymbolGraph {
    static let kindMap1: [String : SwiftDeclarationKind] = [
        "swift.class" : .class,
        "swift.struct" : .struct,
        "swift.enum" : .enum,
        "swift.enum.case" : .enumelement, // 10 out of 10 apple
        "swift.protocol" : .protocol,
        "swift.init" : .functionConstructor,
        "swift.deinit" : .functionDestructor,
        "swift.func.op" : .functionOperator,
        "swift.type.method" : .functionMethodClass,
        "swift.static.method": .functionMethodStatic,
        "swift.method" : .functionMethodInstance,
        "swift.func" : .functionFree,
        "swift.type.property" : .varClass,
        "swift.static.property" : .varStatic,
        "swift.property" : .varInstance,
        "swift.var" : .varGlobal,
        "swift.subscript" : .functionSubscript,
        "swift.typealias" : .typealias,
        "swift.associatedtype" : .associatedtype
    ]

    static let kindMap2: [String: SwiftDeclarationKind2] = [
        "swift.type.subscript" : .functionSubscriptClass,
        "swift.static.subscript" : .functionSubscriptStatic
    ]

    /// "What is StaticSpelling..."
    static func fixUpKind(_ kind: String, declaration: String) -> String {
        guard declaration.re_isMatch(#"\bstatic\b"#) else {
            return kind
        }
        switch kind {
        case "swift.type.method": return "swift.static.method"
        case "swift.type.property": return "swift.static.property"
        case "swift.type.subscript": return "swift.static.subscript"
        default: return kind
        }
    }

    static func mapKind(_ kind: String, declaration: String) -> String? {
        let fixedKind = fixUpKind(kind, declaration: declaration)
        return kindMap1[fixedKind]?.rawValue ?? kindMap2[fixedKind]?.rawValue
    }
}

// MARK: Rebuilder

/// Layer to reapply the relationships and rebuild the AST shape
///
extension SymbolGraph {
    fileprivate final class Node {
        let symbol: Symbol
        var children: SortedArray<Node> {
            didSet {
                children.forEach { $0.parent = self }
            }
        }
        weak var parent: Node?
        var isOverride: Bool

        init(symbol: Symbol) {
            self.symbol = symbol
            self.children = SortedArray<Node>()
            self.parent = nil
            self.isOverride = false
        }

        var declarationXml: String {
            let availabilityXml = symbol.availability.map {
                "<syntaxtype.attribute.builtin>\($0.htmlEscaped)\n</syntaxtype.attribute.builtin>"
            }
            return "<swift>\(availabilityXml.joined())\(symbol.declaration.htmlEscaped)</swift>"
        }

        var asSourceKittenDict: SourceKittenDict {
            var dict = SourceKittenDict()
            dict[.kind] = symbol.kind
            dict[.usr] = symbol.usr
            dict[.name] = symbol.name
            dict[.accessibility] = symbol.accessLevel
            dict[.fullyAnnotatedDecl] = declarationXml
            if !symbol.availability.isEmpty {
                dict[.attributes] = [] // marker for GatherSwiftDecl
            }
            dict[.documentationComment] = symbol.docComment
            dict[.filePath] = symbol.location?.filename
            dict[.docLine] = symbol.location.flatMap { Int64($0.line) }
            dict[.docColumn] = symbol.location.flatMap { Int64($0.character) }
            if isOverride {
                dict[.overrides] = [] // marker for GatherSwiftDecl
            }
            var childDicts = [SourceKittenDict]()
            if !children.isEmpty {
                childDicts += children.map { $0.asSourceKittenDict }
            }
            if !symbol.genericParameters.isEmpty {
                childDicts += symbol.genericParameters.map { $0.asGenericTypeParam }
            }
            if !childDicts.isEmpty {
                dict[.substructure] = childDicts
            }
            return dict
        }
    }

    func rebuild() -> SourceKittenDict {
        var nodes = [String: Node]()
        symbols.forEach { nodes[$0.usr] = Node(symbol: $0) }

        rels.forEach { rel in
            switch rel.kind {
            case .memberOf:
                // "source is a member of target"
                guard let srcNode = nodes[rel.sourceUSR],
                    let tgtNode = nodes[rel.targetUSR] else {
                        logWarning("Can't resolve ends of `memberOf`: \(rel).")
                        break
                }
                tgtNode.children.insert(srcNode)

            case .overrides:
                // "source is overriding target" - only for classes, protocols broken
                guard let srcNode = nodes[rel.sourceUSR] else {
                    logWarning("Can't resolve source of `overrides`: \(rel)")
                    break
                }
                srcNode.isOverride = true

            case .conformsTo,
                 .inheritsFrom,
                 .defaultImplementationOf,
                 .requirementOf,
                 .optionalRequirementOf:
                break
            }
        }
        let rootNodes = nodes.values.filter { $0.parent == nil }.sorted()
        var rootDict = SourceKittenDict()
        rootDict[.diagnosticStage] = "parse"
        rootDict[.substructure] = rootNodes.map { $0.asSourceKittenDict }
        return rootDict
    }
}

private extension String {
    var asGenericTypeParam: SourceKittenDict {
        var dict = SourceKittenDict()
        dict[.name] = self
        dict[.fullyAnnotatedDecl] = "<g>\(self)</g>"
        dict[.usr] = "::FABRICATED-GENPARAM::\(self)"
        dict[.kind] = SwiftDeclarationKind.genericTypeParam.rawValue
        return dict
    }
}

// MARK: Decl Sort Order

extension SymbolGraph.Node: Comparable {
    static func == (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        lhs.symbol == rhs.symbol
    }

    /// Ideally sort by filename and line.  For some reason though swift only gives us locations for
    /// random symbols, so to give a stable order we put those guys at the end in name/usr order.
    static func < (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        if let lhsLocation = lhs.symbol.location,
            let rhsLocation = rhs.symbol.location {
            if lhsLocation.filename == rhsLocation.filename {
                if lhsLocation.line == rhsLocation.line {
                    return lhsLocation.character < rhsLocation.character
                }
                return lhsLocation.line < rhsLocation.line
            }
            return lhsLocation.filename < rhsLocation.filename
        } else if lhs.symbol.location == nil && rhs.symbol.location != nil {
            return false
        } else if lhs.symbol.location != nil && rhs.symbol.location == nil {
            return true
        }
        if lhs.symbol.name == rhs.symbol.name {
            return lhs.symbol.usr < rhs.symbol.usr
        }
        return lhs.symbol.name < rhs.symbol.name
    }
}
