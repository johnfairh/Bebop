//
//  GatherSymbolGraph.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
    struct Constraint: Equatable {
        enum Kind: String {
            case conformance
            case superclass
            case sameType
        }
        let kind: Kind
        let lhs: String
        let rhs: String
    }
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
        let genericTypeParameters: Set<String>
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

            var isProtocolReq: Bool {
                self == .requirementOf || self == .optionalRequirementOf
            }
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
                logWarning(.wrnSsgeSymbolKind, sym.kind.identifier)
                return nil
            }
            guard let acl = DefAcl(rawValue: sym.accessLevel)?.sourceKitName else {
                logWarning(.wrnSsgeSymbolAcl, sym.accessLevel)
                return nil
            }
            let location = sym.location.flatMap {
                Symbol.Location(filename: $0.file, line: $0.position.line, character: $0.position.character)
            }
            // if we're a generic context (includes funcs) then we get a 'swiftGenerics'.
            // if we're not, but are in an extension (with constraints) we get a 'swiftExtension'...
            // Apr16: now we can get both!  And there can be repetitions!
            let constraintList = (sym.swiftGenerics?.constraints ?? []) +
                                 (sym.swiftExtension?.constraints ?? [])
            let constraints = constraintList.compactMap { con -> Constraint? in
                // Drop implementation Self constraint for protocol members
                // Apr16: These are supposed to be gone but some remain.
                if con.lhs == "Self" && con.kind == "conformance" && sym.pathComponents.contains(con.rhs) {
                    return nil
                }
                return Constraint(con)
            }
            // distill what the doc comment is, and whether any have range info: use this
            // as a crap hint that it's been inherited.
            let docComments = sym.docComment?.lines.reduce((false, [String]())) { r, l in
                (r.0 || l.range != nil, r.1 + [l.text])
            }
            return Symbol(kind: kind,
                          usr: sym.identifier.precise,
                          pathComponents: sym.pathComponents,
                          name: sym.pathComponents.last ?? "??",// 9th Jun: names.title is now oddly qualfified
                          docComment: docComments?.1.joined(separator: "\n"),
                          docCommentHasSourceInfo: docComments?.0 ?? false,
                          declaration: declaration,
                          accessLevel: acl,
                          availability: sym.availability?.compactMap { $0.asSwift } ?? [],
                          location: location,
                          genericTypeParameters: Set(sym.swiftGenerics?.parameters?.map { $0.name } ?? []),
                          constraints: Constraints(sorted: constraints.sorted().uniqued()))
        }

        // Relationships
        rels = network.relationships.compactMap { rel in
            guard let kind = Rel.Kind(rawValue: rel.kind) else {
                logWarning(.localized(.wrnSsgeRelKind, rel.kind))
                return nil
            }
            let constraints = rel.swiftConstraints?.compactMap(Constraint.init) ?? []
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

        if isUnconditionallyDeprecated != nil {
            str += "*, deprecated"
        } else if let domain = domain {
            str += domain
            [("introduced", \Self.introduced),
             ("deprecated", \Self.deprecated),
             ("obsoleted", \Self.obsoleted)].forEach { name, kp in
                if let version = self[keyPath: kp] {
                    str += ", \(name): \(version.asSwift)"
                }
            }
        } else {
            logWarning(.wrnSsgeAvailability)
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

fileprivate extension SymbolGraph.Constraint.Kind {
    var asSwift: String {
        switch self {
        case .conformance: return ":"
        case .superclass: return ":"
        case .sameType: return "=="
        }
    }
}

extension SymbolGraph.Constraint: Comparable {
    fileprivate static func < (lhs: SymbolGraph.Constraint, rhs: SymbolGraph.Constraint) -> Bool {
        lhs.asSwift < rhs.asSwift
    }

    fileprivate init?(_ con: NetworkSymbolGraph.Constraint) {
        guard let kindVal = Kind(rawValue: con.kind) else {
            logWarning(.wrnSsgeConstKind, con.kind)
            return nil
        }
        self.lhs = con.lhs.unselfed
        self.kind = kindVal
        self.rhs = con.rhs.unselfed
    }

    var asSwift: String {
        "\(lhs) \(kind.asSwift) \(rhs)"
    }

    var typeNames: Set<String> {
        [lhs.firstComponent, rhs.firstComponent]
    }
}

private extension String {
    /// Remove any leading `Self.`
    var unselfed: String {
        re_sub(#"^Self\."#, with: "")
    }
    /// Remove any dot and after
    var firstComponent: String {
        re_sub(#"\..*$"#, with: "")
    }
}

extension SymbolGraph.Constraints {
    /// These constraints except anything in `other`
    func subtracting(_ other: Self) -> Self {
        filter { !other.contains($0) }
    }

    var asKey: String {
        map { $0.asSwift }.joined()
    }

    // A 'where' clause for these constraints - includes leading space.  Empty string if no constraints.
    var asWhereClause: String {
        guard !isEmpty else { return "" }
        return " where " + map { $0.asSwift }.joined(separator: ", ")
    }
}

// MARK: Declaration Fixup

extension SymbolGraph {
    /// Work around bugs/bad design in ssge's declprinter
    static func fixUpDeclaration(_ declaration: String) -> String {
        var fixed = declaration
            // All these Selfs are pointless & I don't want to teach autolink about them
            .re_sub(#"\bSelf\."#, with: "")
            // Try to fix up `func(_: Int)` stuff
            // Apr16: fixed for funcs, still broken for enums...
            .re_sub(#"(?<=\(|, )_: "#, with: "_ arg: ")

        if fixed.re_isMatch(#"\bsubscript\b"#) {
            // ...and broken in the other direction for subscripts
            // XXX is this really right?  What is 'broken' here?
            fixed = fixed.re_sub(#"(?<=\(|, )(\w+:)"#, with: "_ $1")
        }
        // Jun 6: now decl duplicates constraints but has lost inheritances...
        return fixed.re_sub(" where.*$", with: "")
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

        var constraints: Constraints {
            Constraints()
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
        var isBad: Bool
        var superclassName: String?

        init(symbol: Symbol) {
            self.symbol = symbol
            self.parent = nil
            self.isOverride = false
            self.isProtocolReq = false
            self.isBad = false
            self.superclassName = nil
        }

        override var constraints: Constraints {
            symbol.constraints
        }

        var qualifiedName: String {
            symbol.pathComponents.joined(separator: ".")
        }

        var isProtocol: Bool {
            symbol.kind == SwiftDeclarationKind.protocol.rawValue
        }

        var isRootDecl: Bool {
            parent == nil && !isBad
        }

        func hasConformance(to protoName: String) -> Bool {
            if let declConformances = symbol.declaration.re_match("(?<=:).*?(?=(where|$))")?[0],
                declConformances.re_isMatch(#"\b\#(protoName)\b"#) {
                return true
            }
            return false
        }

        /// Add a member if possible: must not further constrain our generic parameters.
        /// And  careful with protocols.
        func tryAdd(member: Node, uniqueContextConstraints: Constraints) -> Bool {
            guard uniqueContextConstraints.isEmpty,
                !isProtocol || member.isProtocolReq else {
                return false
            }
            children.insert(member)
            return true
        }

        /// The constraints on this declaration that are both:
        /// 1. Unique to the declaration, ie. not just inherited wholesale from the parent; and
        /// 2. Constraining the parent's generic parameters, rather than our own.
        func uniqueContextConstraints(context: Node?) -> Constraints {
            guard let context = context else { return symbol.constraints }

            let newGenericTypeParameters =
                symbol.genericTypeParameters
                    .subtracting(context.symbol.genericTypeParameters)

            return symbol.constraints.subtracting(context.symbol.constraints)
                .filter { $0.typeNames.intersection(newGenericTypeParameters).isEmpty }
        }

        var declarationXml: String {
            let availabilityXml = symbol.availability.map {
                "<syntaxtype.attribute.builtin>\($0.htmlEscaped)\n</syntaxtype.attribute.builtin>"
            }
            let newConstraints = symbol.constraints.subtracting(parent?.constraints ?? Constraints())
            let inherits = superclassName.flatMap { " : \($0)"} ?? ""
            let declaration = symbol.declaration + inherits + newConstraints.asWhereClause
            return "<swift>\(availabilityXml.joined())\(declaration.htmlEscaped)</swift>"
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
            if !symbol.genericTypeParameters.isEmpty {
                childDicts += symbol.genericTypeParameters.sorted().map { $0.asGenericTypeParam }
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
        let extConstraints: Constraints
        let typeConstraints: Constraints
        var conformances: SortedArray<String>

        override var constraints: Constraints {
            var allConstraints = extConstraints
            allConstraints.insert(contentsOf: typeConstraints)
            return allConstraints
        }

        /// Deduce an extension from a member of a possibly unknown type
        init(forMember member: Node, typeUSR: String, typeConstraints: Constraints?, extConstraints: Constraints) {
            self.typeUSR = typeUSR
            self.name = member.symbol.pathComponents.dropLast().joined(separator: ".")
            self.extConstraints = extConstraints
            self.typeConstraints = typeConstraints ?? Constraints()
            self.conformances = SortedArray()
            super.init()
            add(member: member)
            logDebug("SymbolGraph: deduced extension for \(name) (\(constraints))")
        }

        /// Deduce an extension from a protocol conformance for some type
        init(forTypeUSR typeUSR: String, typeName: String, typeConstraints: Constraints?, extConstraints: Constraints, proto: String) {
            self.typeUSR = typeUSR
            self.name = typeName
            self.extConstraints = extConstraints
            self.typeConstraints = typeConstraints ?? Constraints()
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
            decl += extConstraints.asWhereClause
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
        let constraints: String
        init(typeUSR: String, constraints: Constraints) {
            self.typeUSR = typeUSR
            self.constraints = constraints.asKey
        }
    }

    struct ExtensionMap {
        var map = [ExtNodeKey : ExtNode]()

        mutating func addMemberOf(member: Node, typeUSR: String, where extConstraints: Constraints, typeConstraints: Constraints?) {
            let key = ExtNodeKey(typeUSR: typeUSR, constraints: extConstraints)
            if let extNode = map[key] {
                extNode.add(member: member)
            } else {
                map[key] = ExtNode(forMember: member,
                                   typeUSR: typeUSR,
                                   typeConstraints: typeConstraints,
                                   extConstraints: extConstraints)
            }
        }

        mutating func addConformance(fromUSR typeUSR: String,
                                     fromName typeName: String,
                                     withTypeConstraints typeConstraints: Constraints?,
                                     to protoName: String,
                                     where extConstraints: Constraints) {
            let key = ExtNodeKey(typeUSR: typeUSR, constraints: extConstraints)
            if let extNode = map[key] {
                extNode.add(conformance: protoName)
            } else {
                map[key] = ExtNode(forTypeUSR: typeUSR,
                                   typeName: typeName,
                                   typeConstraints: typeConstraints,
                                   extConstraints: extConstraints,
                                   proto: protoName)
            }
        }
    }

    // MARK: Builder

    func rebuild(moduleName: String) -> SourceKittenDict {
        var nodes = [String: Node]()
        symbols.forEach { nodes[$0.usr] = Node(symbol: $0) }

        var extensionMap = ExtensionMap()

        logDebug("SymbolGraph: start rebuilding AST shape")

        // Apr16: protocol requirements are fixed to go single-pass, but
        // now we have to process default implementation rels after everything else.
        let (defaultImpls, otherRels) = rels.splitPartition {
            $0.kind == .defaultImplementationOf
        }

        func resolveSource(rel: Rel) -> Node? {
            guard let srcNode = nodes[rel.sourceUSR] else {
                logWarning(.wrnSsgeBadSrcUsr, rel.sourceUSR, rel.kind)
                return nil
            }
            return srcNode
        }

        otherRels.forEach { rel in
            switch rel.kind {
            case .memberOf, .optionalRequirementOf, .requirementOf:
                // "source is a member/requirement of target"
                guard let srcNode = resolveSource(rel: rel) else {
                    break
                }
                srcNode.isProtocolReq = rel.kind.isProtocolReq

                let tgtNode = nodes[rel.targetUSR]
                let contextConstraints = srcNode.uniqueContextConstraints(context: tgtNode)
                if tgtNode?.tryAdd(member: srcNode, uniqueContextConstraints: contextConstraints) ?? false {
                    break
                }

                extensionMap.addMemberOf(member: srcNode,
                                         typeUSR: rel.targetUSR,
                                         where: contextConstraints,
                                         typeConstraints: tgtNode?.constraints)

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

                let typeConstraints = srcNode?.symbol.constraints ?? .init()
                let extConstraints = rel.constraints.subtracting(typeConstraints)

                extensionMap.addConformance(fromUSR: rel.sourceUSR,
                                            fromName: srcName,
                                            withTypeConstraints: typeConstraints,
                                            to: protocolName,
                                            where: extConstraints)
                break

            case .inheritsFrom:
                // "source : target" where target is a class
                if let srcNode = resolveSource(rel: rel)  {
                    srcNode.superclassName = nodes[rel.targetUSR]?.symbol.name ?? rel.targetUSR
                }

            case .defaultImplementationOf:
                // do later
                break
            }
        }

        // Now we've mapped requirements to their types we have a chance of figuring
        // out default implementations.
        defaultImpls.forEach { rel in
            // "'source' is a default implementation of protocol requirement 'target'"
            guard let srcNode = resolveSource(rel: rel) else {
                return
            }
            guard let tgtNode = nodes[rel.targetUSR],
                let tgtNodeParent = tgtNode.parent as? Node else {
                logWarning(.wrnSsgeBadDefaultReq, rel.targetUSR)
                // Don't include this weird thing in docs
                // (OK we could probably decode the tgtNode USR or something, but this
                // is a weird case and is swift's fault to fix.)
                srcNode.isBad = true
                return
            }

            let contextConstraints = srcNode.uniqueContextConstraints(context: tgtNodeParent)
            extensionMap.addMemberOf(member: srcNode,
                                     typeUSR: tgtNodeParent.symbol.usr,
                                     where: contextConstraints,
                                     typeConstraints: tgtNodeParent.constraints)
        }

        let rootTypeNodes = nodes.values.filter(\.isRootDecl).sorted()
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
        lhs.name == rhs.name && lhs.constraints.asKey == rhs.constraints.asKey
    }

    fileprivate static func < (lhs: SymbolGraph.ExtNode, rhs: SymbolGraph.ExtNode) -> Bool {
        if lhs.name == rhs.name {
            return lhs.constraints.asKey < rhs.constraints.asKey
        }
        return lhs.name < rhs.name
    }
}
