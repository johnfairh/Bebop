//
//  GatherSymbolGraph.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

enum GatherSymbolGraph {

    static func decode(moduleName: String, json: String) throws -> GatherDef {
        logDebug("Decoding main symbolgraph JSON for \(moduleName)")
        try doFile(json: json)
        //loginfo when done
        return GatherDef(children: [], sourceKittenDict: SourceKittenDict(), kind: nil, swiftDeclaration: nil, objCDeclaration: nil, documentation: nil, localizationKey: nil, translatedDocs: nil)
    }

    static func decode(moduleName: String, otherModuleName: String, json: String) throws -> GatherDef {
        logDebug("Decoding extension symbolgraph JSON for \(moduleName) from \(otherModuleName)")
        try doFile(json: json)

        //loginfo when done
        return GatherDef(children: [], sourceKittenDict: SourceKittenDict(), kind: nil, swiftDeclaration: nil, objCDeclaration: nil, documentation: nil, localizationKey: nil, translatedDocs: nil)
    }

    static func doFile(json: String) throws {
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: json.data(using: .utf8)!)
        graph.rebuild()
    }
}

/// Honest representation of the JSON with stuff we don't want omitted.
/// About as fragile as hard-coding keys I suppose.
fileprivate struct NetworkSymbolGraph: Decodable {
    struct Metadata: Decodable {
        let generator: String
    }
    let metadata: Metadata
    struct Symbol: Decodable {
        struct Kind: Decodable {
            let identifier: String
        }
        let kind: Kind
        struct Identifier: Decodable {
            let precise: String
        }
        let identifier: Identifier
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
        let declarationFragments: [DeclFrag]
        let accessLevel: String
        struct Location: Decodable {
            let uri: String
            var file: String? {
                URL(string: uri)?.path
            }
            struct Position: Decodable {
                let line: Int
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
    }
    let relationships: [Rel]
}

/// Flattened and more normally-named deserialized symbolgraph - all decoding of json happens here.
fileprivate struct SymbolGraph: Decodable {
    let generator: String
    struct Symbol {
        let kind: String
        let usr: String
        let name: String
        let docComment: String?
        let declaration: String
        let accessLevel: String
        let filename: String?
        let line: Int?
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
    }
    let rels: [Rel]

    init(from decoder: Decoder) throws {
        let network = try NetworkSymbolGraph(from: decoder)
        generator = network.metadata.generator
        symbols = network.symbols.compactMap {
            guard let kind = Self.mapKind($0.kind.identifier) else {
                logWarning("Unknown swift-symbolgraph symbol kind '\($0.kind.identifier)', ignoring.")
                return nil
            }
            guard let acl = DefAcl(rawValue: $0.accessLevel)?.sourceKitName else {
                logWarning("Unknown swift-symbolgraph access level '\($0.accessLevel)', ignoring.")
                return nil
            }
            return Symbol(kind: kind,
                          usr: $0.identifier.precise,
                          name: $0.names.title,
                          docComment: $0.docComment?.lines.map { $0.text }.joined(separator: "\n"),
                          declaration: $0.declarationFragments.map { $0.spelling }.joined(),
                          accessLevel: acl,
                          filename: $0.location?.file,
                          line: $0.location?.position.line)
        }
        rels = network.relationships.compactMap {
            guard let kind = Rel.Kind(rawValue: $0.kind) else {
                logWarning("Unknown swift-symbolgraph relationship kind '\($0.kind)', ignoring.")
                return nil
            }
            return Rel(kind: kind,
                       sourceUSR: $0.source,
                       targetUSR: $0.target,
                       targetFallback: $0.targetFallback)
        }
    }

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
        "swift.method" : .functionMethodInstance,
        "swift.func" : .functionFree,
        "swift.type.property" : .varClass,
        "swift.property" : .varInstance,
        "swift.var" : .varGlobal,
        "swift.subscript" : .functionSubscript,
        "swift.typealias" : .typealias,
        "swift.associatedtype" : .associatedtype
    ]

    static let kindMap2: [String: SwiftDeclarationKind2] = [
        "swift.type.subscript" : .functionSubscriptClass
    ]

    static func mapKind(_ from: String) -> String? {
        kindMap1[from]?.rawValue ?? kindMap2[from]?.rawValue
    }
}

/// Layer to reapply the relationships

extension SymbolGraph {

    private final class Node {
        let symbol: Symbol
        var children: [Node] {
            didSet {
                children.forEach { $0.parent = self }
            }
        }
        weak var parent: Node?

        init(symbol: Symbol) {
            self.symbol = symbol
            self.children = []
            self.parent = nil
        }
    }

    func rebuild() {
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
                tgtNode.children.append(srcNode)

            case .conformsTo,
                 .inheritsFrom,
                 .defaultImplementationOf,
                 .overrides,
                 .requirementOf,
                 .optionalRequirementOf:
                break
            }
        }
        let rootNodes = nodes.values.filter { $0.parent == nil }
        rootNodes.forEach { print("\($0.symbol.name): \($0.symbol.declaration)") }

        // node -> sourcekittendict
        // 'mkfile' to hold all the rootNodes
    }
}
