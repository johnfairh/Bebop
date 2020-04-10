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
        logDebug("SymbolGraph: decoding data for module \(extensionModuleName)")
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)
        return graph.rebuild(moduleName: extensionModuleName)
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
        struct Position: Decodable {
            let line: Int
            let character: Int
        }
        struct DocCommentLines: Decodable {
            struct DocCommentLine: Decodable {
                struct Range: Decodable {
                    let start: Position
                    let end: Position
                }
                let range: Range?
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
        struct SwiftExtension: Decodable {
            let extendedModule: String
            let constraints: [Constraint]?
        }
        let swiftExtension: SwiftExtension?
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
    typealias Constraint = String
    typealias Constraints = SortedArray<Constraint>

    struct Symbol: Equatable {
        let kind: String
        let usr: String
        let pathComponents: [String]
        let name: String
        let docComment: String?
        let docCommentHasSourceInfo: Bool
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
        let constraints: Constraints
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
        let constraints: Constraints
    }
    let rels: [Rel]

    init(from decoder: Decoder) throws {
        let network = try NetworkSymbolGraph(from: decoder)
        logDebug("SymbolGraph: decoded JSON, generator: \(network.metadata.generator)")

        // Symbols
        symbols = network.symbols.compactMap { sym in
            let declaration = Self.fixUpDeclaration(sym.declarationFragments.map { $0.spelling }.joined())
            guard let kind = Self.mapKind(sym.kind.identifier, declaration: declaration) else {
                logWarning(.localized(.wrnSsgeSymbolKind, sym.kind.identifier))
                return nil
            }
            guard let acl = DefAcl(rawValue: sym.accessLevel)?.sourceKitName else {
                logWarning(.localized(.wrnSsgeSymbolAcl, sym.accessLevel))
                return nil
            }
            let location = sym.location.flatMap {
                Symbol.Location(filename: $0.file, line: $0.position.line, character: $0.position.character)
            }
            // if we're a generic context (includes funcs) then we get a 'swiftGenerics'.
            // if we're not, but are in an extension (with constraints) we get a 'swiftExtension'...
            let constraintList = sym.swiftGenerics?.constraints ?? sym.swiftExtension?.constraints ?? []
            let constraints = constraintList.compactMap { con -> Constraint? in
                // Drop implementation Self constraint for protocol members
                if con.lhs == "Self" && con.kind == "conformance" && sym.pathComponents.contains(con.rhs) {
                    return nil
                }
                return con.asSwift
            }
            // distill what the doc comment is, and whether any have range info: use this
            // as a crap hint that it's been inherited.
            let docComments = sym.docComment?.lines.reduce((false, [String]())) { r, l in
                (r.0 || l.range != nil, r.1 + [l.text])
            }
            return Symbol(kind: kind,
                          usr: sym.identifier.precise,
                          pathComponents: sym.pathComponents,
                          name: sym.names.title,
                          docComment: docComments?.1.joined(separator: "\n"),
                          docCommentHasSourceInfo: docComments?.0 ?? false,
                          declaration: declaration,
                          accessLevel: acl,
                          availability: sym.availability?.compactMap { $0.asSwift } ?? [],
                          location: location,
                          genericParameters: sym.swiftGenerics?.parameters?.map { $0.name } ?? [],
                          constraints: Constraints(unsorted: constraints))
        }

        // Relationships
        rels = network.relationships.compactMap { rel in
            guard let kind = Rel.Kind(rawValue: rel.kind) else {
                logWarning(.localized(.wrnSsgeRelKind, rel.kind))
                return nil
            }
            let constraints = rel.swiftConstraints?.compactMap { $0.asSwift } ?? []
            return Rel(kind: kind,
                       sourceUSR: rel.source,
                       targetUSR: rel.target,
                       targetFallback: rel.targetFallback?.re_sub(#"^.*?\."#, with: ""), // drop module name,
                       constraints: Constraints(unsorted: constraints))
        }
        logDebug("SymbolGraph: further decoded JSON, \(symbols.count) symbols, \(rels.count) rels")
    }
}

// MARK: @available

extension NetworkSymbolGraph.Symbol.Availability {
    /// Reconstitute the "@available" statement so that we can push it through SwiftSyntax.  Good game, good game.
    var asSwift: String? {
        var str = "@available("

        if let domain = domain {
            str += domain
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
            logWarning(.localized(.wrnSsgeAvailability))
            return nil
        }

        if let message = message {
            str += #", message: "\#(message)""#
        }
        if let renamed = renamed {
            str += #", renamed: "\#(renamed)""#
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

// MARK: Constraint

private extension String {
    var unselfed: String {
        re_sub(#"^Self\."#, with: "")
    }
}

extension NetworkSymbolGraph.Constraint {
    var asSwift: String? {
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

        guard let kindVal = Kind(rawValue: kind) else {
            logWarning(.localized(.wrnSsgeConstKind, kind))
            return nil
        }
        return "\(lhs.unselfed) \(kindVal.swift) \(rhs.unselfed)"
    }
}

// MARK: Declaration Fixup

extension SymbolGraph {
    /// Work around bugs/bad design in ssge's declprinter
    static func fixUpDeclaration(_ declaration: String) -> String {
        declaration
            // All these Selfs are pointless & I don't want to teach autolink about them
            .re_sub(#"\bSelf\."#, with: "")
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

    /// We prefer to differentiate on 'static spelling' - TSPL papers over the distinction.
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
    class ParentNode {
        var children: SortedArray<Node> {
            didSet {
                children.forEach { $0.parent = self }
            }
        }

        init() {
            self.children = SortedArray()
        }
    }

    // MARK: Types

    final class Node: ParentNode {
        let symbol: Symbol
        weak var parent: ParentNode?
        var isOverride: Bool
        var isProtocolReq: Bool

        init(symbol: Symbol) {
            self.symbol = symbol
            self.parent = nil
            self.isOverride = false
            self.isProtocolReq = false
        }

        var qualifiedName: String {
            symbol.pathComponents.joined(separator: ".")
        }

        var isProtocol: Bool {
            symbol.kind == SwiftDeclarationKind.protocol.rawValue
        }

        func hasConformance(to protoName: String) -> Bool {
            if let declConformances = symbol.declaration.re_match("(?<=:).*?(?=(where|$))")?[0],
                declConformances.re_isMatch(#"\b\#(protoName)\b"#) {
                return true
            }
            return false
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
            dict[.fullXMLDocs] = symbol.docComment == nil ? "" : nil
            dict[.inheritedDocs] = !symbol.docCommentHasSourceInfo
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

    // MARK: Extensions

    final class ExtNode: ParentNode {
        let typeUSR: String
        let name: String
        let constraints: Constraints
        var conformances: SortedArray<String>

        /// Deduce an extension from a member of an unknown type
        init(forMember member: Node, typeUSR: String) {
            self.typeUSR = typeUSR
            self.name = member.symbol.pathComponents.dropLast().joined(separator: ".")
            self.constraints = member.symbol.constraints
            self.conformances = SortedArray()
            super.init()
            add(member: member)
            logDebug("SymbolGraph: deduced extension for \(name) (\(constraints))")
        }

        /// Deduce an extension from a protocol conformance for some type
        init(forTypeUSR typeUSR: String, typeName: String, constraints: Constraints, proto: String) {
            self.typeUSR = typeUSR
            self.name = typeName
            self.constraints = constraints
            self.conformances = SortedArray()
            super.init()
            add(conformance: proto)
            logDebug("SymbolGraph: deduced extension for \(name): \(proto) (\(constraints))")
        }

        func add(member: Node) {
            children.insert(member)
        }

        func add(conformance: String) {
            conformances.insert(conformance)
        }

        var declarationXml: String {
            var decl = "extension \(name)"
            if !conformances.isEmpty {
                decl += " : " + conformances.joined(separator: ", ")
            }
            if !constraints.isEmpty {
                decl += " where " + constraints.joined(separator: ", ")
            }
            return "<swift>\(decl.htmlEscaped)</swift>"
        }

        func asSourceKittenDict(moduleName: String) -> SourceKittenDict {
            var dict = SourceKittenDict()
            dict[.kind] = SwiftDeclarationKind.extension.rawValue
            dict[.usr] = typeUSR
            dict[.name] = name
            dict[.moduleName] = moduleName
            dict[.fullyAnnotatedDecl] = declarationXml
            if !conformances.isEmpty {
                dict[.inheritedtypes] = conformances.map { [SwiftDocKey.name.rawValue: $0] }
            }
            if !children.isEmpty {
                dict[.substructure] = children.map { $0.asSourceKittenDict }
            }
            return dict
        }
    }

    struct ExtNodeKey: Hashable {
        let typeUSR: String
        let constraints: Constraints
    }

    struct ExtensionMap {
        var map = [ExtNodeKey : ExtNode]()

        mutating func addMemberOf(member: Node, typeUSR: String) {
            let key = ExtNodeKey(typeUSR: typeUSR, constraints: member.symbol.constraints)
            if let extNode = map[key] {
                extNode.add(member: member)
            } else {
                map[key] = ExtNode(forMember: member, typeUSR: typeUSR)
            }
        }

        mutating func addConformance(fromUSR typeUSR: String,
                                     fromName typeName: String,
                                     to protoName: String,
                                     where constraints: Constraints = Constraints()) {
            let key = ExtNodeKey(typeUSR: typeUSR, constraints: constraints)
            if let extNode = map[key] {
                extNode.add(conformance: protoName)
            } else {
                map[key] = ExtNode(forTypeUSR: typeUSR, typeName: typeName, constraints: constraints, proto: protoName)
            }
        }
    }

    // MARK: Builder

    func rebuild(moduleName: String) -> SourceKittenDict {
        var nodes = [String: Node]()
        symbols.forEach { nodes[$0.usr] = Node(symbol: $0) }

        var extensionMap = ExtensionMap()

        logDebug("SymbolGraph: start rebuilding AST shape")

        // We have to mark up protocol requirements before handling their memberOfs.
        // Just split them out and process.
        let (protoReqs, otherRels) = rels.splitPartition {
            $0.kind == .requirementOf || $0.kind == .optionalRequirementOf
        }

        func resolveSource(rel: Rel) -> Node? {
            guard let srcNode = nodes[rel.sourceUSR] else {
                logWarning("Can't resolve source=\(rel.sourceUSR) for \(rel.kind).")
                return nil
            }
            return srcNode
        }

        protoReqs.forEach {
            // "source is a requirement of protocol target"
            resolveSource(rel: $0)?.isProtocolReq = true
        }

        otherRels.forEach { rel in
            switch rel.kind {
            case .memberOf:
                // "source is a member of target"
                guard let srcNode = resolveSource(rel: rel) else {
                    break
                }
                if let tgtNode = nodes[rel.targetUSR],
                    tgtNode.symbol.constraints == srcNode.symbol.constraints,
                    // don't put default impls/extn methods in the protocol
                    !tgtNode.isProtocol || srcNode.isProtocolReq {
                    tgtNode.children.insert(srcNode)
                } else {
                    extensionMap.addMemberOf(member: srcNode, typeUSR: rel.targetUSR)
                }

            case .overrides:
                // "source is overriding target" - only for classes, protocols broken
                resolveSource(rel: rel)?.isOverride = true

            case .conformsTo:
                // "source : target" either from type decl or ext decl
                let srcNode = nodes[rel.sourceUSR]
                let tgtNode = nodes[rel.targetUSR]

                let protocolName = tgtNode?.symbol.name ??
                    rel.targetFallback ??
                    USR(rel.targetUSR).swiftDemangled ??
                    rel.targetUSR

                // Special case: if the conformance is unconditional from one of our types
                // then it may already be written down in the type's decl: if so do nothing.
                if let srcNode = srcNode,
                    rel.constraints.isEmpty,
                    srcNode.hasConformance(to: protocolName) {
                    break
                }

                let srcName = srcNode?.qualifiedName ??
                    USR(rel.sourceUSR).swiftDemangled ?? // where my sourceFallback at bra
                    rel.sourceUSR

                extensionMap.addConformance(fromUSR: rel.sourceUSR,
                                            fromName: srcName,
                                            to: protocolName,
                                            where: rel.constraints)
                break

            case .inheritsFrom, // don't care
                 .defaultImplementationOf, // don't care
                 .requirementOf, // already processed
                 .optionalRequirementOf: // already processed
                break
            }
        }
        let rootTypeNodes = nodes.values.filter { $0.parent == nil }.sorted()
        let rootExtNodes = extensionMap.map.values.sorted()
        logDebug("SymbolGraph: after rebuild, \(rootTypeNodes.count) root types, \(rootExtNodes.count) root exts.")

        var rootDict = SourceKittenDict()
        rootDict[.diagnosticStage] = "parse"
        rootDict[.substructure] =
            rootTypeNodes.map { $0.asSourceKittenDict } +
            rootExtNodes.map { $0.asSourceKittenDict(moduleName: moduleName) }
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
    fileprivate static func == (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        lhs.symbol == rhs.symbol
    }

    /// Ideally sort by filename and line.  For some reason though swift only gives us locations for
    /// public+ symbols, so to give a stable order we put the others at the end in name/usr order.
    fileprivate static func < (lhs: SymbolGraph.Node, rhs: SymbolGraph.Node) -> Bool {
        if let lhsLocation = lhs.symbol.location,
            let rhsLocation = rhs.symbol.location {
            if lhsLocation.filename == rhsLocation.filename {
                if lhsLocation.line == rhsLocation.line {
                    return lhsLocation.character < rhsLocation.character
                }
                return lhsLocation.line < rhsLocation.line
            }
            return lhsLocation.filename < rhsLocation.filename
        }
        if lhs.symbol.location == nil && rhs.symbol.location != nil {
            return false
        }
        if lhs.symbol.location != nil && rhs.symbol.location == nil {
            return true
        }
        if lhs.symbol.name == rhs.symbol.name {
            return lhs.symbol.usr < rhs.symbol.usr
        }
        return lhs.symbol.name < rhs.symbol.name
    }
}

// Fabricated extensions go afterwards, no source location

extension SymbolGraph.ExtNode: Comparable {
    fileprivate static func == (lhs: SymbolGraph.ExtNode, rhs: SymbolGraph.ExtNode) -> Bool {
        lhs.name == rhs.name && lhs.constraints == rhs.constraints
    }

    fileprivate static func < (lhs: SymbolGraph.ExtNode, rhs: SymbolGraph.ExtNode) -> Bool {
        if lhs.name == rhs.name {
            return lhs.constraints.joined() < rhs.constraints.joined()
        }
        return lhs.name < rhs.name
    }
}
