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

enum GatherSymbolGraph {

    static func decode(moduleName: String, json: String) throws -> GatherDef? {
        logDebug("Decoding main symbolgraph JSON for \(moduleName)")
        let dict = try doFile(json: json)
        return GatherDef(sourceKittenDict: dict, parentNameComponents: [], file: nil, availability: Gather.Availability())
        //loginfo when done
    }

    static func decode(moduleName: String, otherModuleName: String, json: String) throws -> GatherDef {
        logDebug("Decoding extension symbolgraph JSON for \(moduleName) from \(otherModuleName)")
        try doFile(json: json)

        //loginfo when done
        return GatherDef(children: [], sourceKittenDict: SourceKittenDict(), kind: nil, swiftDeclaration: nil, objCDeclaration: nil, documentation: nil, localizationKey: nil, translatedDocs: nil)
    }

    static func doFile(json: String) throws -> SourceKittenDict {
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: json.data(using: .utf8)!)
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

// MARK: Decoder

/// Flattened and more normally-named deserialized symbolgraph - all decoding of json happens here.
fileprivate struct SymbolGraph: Decodable {
    let generator: String
    struct Symbol: Equatable {
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
            return Symbol(kind: kind,
                          usr: sym.identifier.precise,
                          name: sym.names.title,
                          docComment: sym.docComment?.lines.map { $0.text }.joined(separator: "\n"),
                          declaration: declaration,
                          accessLevel: acl,
                          filename: sym.location?.file,
                          line: sym.location?.position.line)
        }
        rels = network.relationships.compactMap { rel in
            guard let kind = Rel.Kind(rawValue: rel.kind) else {
                logWarning("Unknown swift-symbolgraph relationship kind '\(rel.kind)', ignoring.")
                return nil
            }
            return Rel(kind: kind,
                       sourceUSR: rel.source,
                       targetUSR: rel.target,
                       targetFallback: rel.targetFallback)
        }
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

/// Layer to reapply the relationships and rebuild the AST
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

        init(symbol: Symbol) {
            self.symbol = symbol
            self.children = SortedArray<Node>()
            self.parent = nil
        }

        var asSourceKittenDict: SourceKittenDict {
            var dict = SourceKittenDict()
            dict[.kind] = symbol.kind
            dict[.usr] = symbol.usr
            dict[.name] = symbol.name
            dict[.accessibility] = symbol.accessLevel
            dict[.fullyAnnotatedDecl] =
                "<swift>\(symbol.declaration.htmlEscaped)</swift>"
            dict[.documentationComment] = symbol.docComment
            dict[.filePath] = symbol.filename
            dict[.docLine] = symbol.line.flatMap(Int64.init)
            if !children.isEmpty {
                dict[.substructure] = children.map { $0.asSourceKittenDict }
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
        var rootDict = SourceKittenDict()
        rootDict["key.diagnostic_stage"] = "parse"
        rootDict[.substructure] = rootNodes.sorted().map { $0.asSourceKittenDict }
        return rootDict
    }
}

// MARK: Decl Sort Order

extension SymbolGraph.Node: Comparable {
    static func == (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        lhs.symbol == rhs.symbol
    }

    var location: (file: String, line: Int)? {
        symbol.filename.flatMap { f in symbol.line.flatMap { (f, $0) } }
    }

    /// Ideally sort by filename and line.  For some reason though swift only gives us locations for
    /// random symbols, so to give a stable order we put those guys at the end in name/usr order.
    static func < (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        if let lhsLocation = lhs.location,
            let rhsLocation = rhs.location {
            if lhsLocation.file == rhsLocation.file {
                return lhsLocation.line < rhsLocation.line
            }
            return lhsLocation.file < rhsLocation.file
        } else if lhs.location == nil && rhs.location != nil {
            return false
        } else if lhs.location != nil && rhs.location == nil {
            return true
        }
        if lhs.symbol.name == rhs.symbol.name {
            return lhs.symbol.usr < rhs.symbol.usr
        }
        return lhs.symbol.name < rhs.symbol.name
    }
}
