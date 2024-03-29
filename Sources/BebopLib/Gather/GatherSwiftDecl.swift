//
//  GatherSwiftDecl.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SWXMLHash
import SourceKittenFramework
import SwiftSyntax

// Swift declaration production.
//
// 1) make a nice-looking declaration
// 2) extract and analyze @available attributes
// 3) generate piece-name declarations
//
// Problems:
// 1) Want to use the standard-form compiler declaration that regularizes
//    whitespace, generic formatting, and does the 'var V = E => var V: T'.
//    This is found in [fully_]annotated_decl from sourcekit, draped in XML.
//    1a) @available attributes are stripped from [fully_]annotated_decl.
//    1b) The compiler declaration has various ugliness that needs plastering.
// 2) Random attributes are stripped from the full_xml declaration (which is
//    absent anyway if no doc comment, so ignore it.)
// 3) Long declarations.  I think we would ideally do multi-line formatting
//    ourselves, manually or SwiftFormat -- need this for objc->swift anyway --
//    but for now we'll take the user's hand-written multi-line one.
// 4) Attributes in sourcekit include some keywords due to their
//    internal implementation.
// 5) Available attributes in sourcekit often REPEAT because of careless
//    compiler implementation leakage.
// 6) Swift decls generated from ObjC code have lost their metadata by the time
//    SourceKitten gives them to us.  On the plus side they don't have any
//    attributes.
//
// Strategy:
// 1) Get declaration attributes directly from sourcekitten data.
// 2) Get compiler declaration from fully_annotated_decl:
//    - strip out attribute elements [bcos incomplete]
//    - convert to text
// 3) Check parsed declaration to see if we prefer it
//    - means newlines.  should really just bash out a naive prettyprinter.
//    - strip leading attributes and unindent
// 4) Do @available empire - extract key facts including deprecation messages
// 5) Form final decl by stacking attributes on decl
// 6) Form name pieces by invoking SwiftSyntax.
//    This is the only option because we don't have decl XML for the ObjC
//    ones.

/// Short-lived workspace for figuring things out about a Swift declaration
class SwiftDeclarationBuilder {
    let dict: SourceKittenDict
    let nameComponents: [String]
    let file: File?
    let kind: DefKind?
    let stripObjC: Bool
    let availabilityRules: Gather.Availability

    var compilerDecl: String?
    var neatParsedDecl: String?
    var attributes: [String] = []
    var deprecations: [Localized<String>] = []
    var deprecatedEverywhere: Bool = false
    var unavailables: [Localized<String>] = []
    var availability: [String] = []

    init(dict: SourceKittenDict,
         nameComponents: [String],
         file: File?,
         kind: DefKind?,
         stripObjC: Bool,
         availabilityRules: Gather.Availability) {
        self.dict = dict
        self.nameComponents = nameComponents
        self.file = file
        self.kind = kind
        self.stripObjC = stripObjC
        self.availabilityRules = availabilityRules
    }

    func build() -> SwiftDeclaration? {
        availability = availabilityRules.defaults // override later if we get that far

        guard let annotatedDecl = dict.fullyAnnotatedDecl else {
            // Means unavailable or something, not an error condition
            return nil
        }

        compilerDecl = parse(annotatedDecl: annotatedDecl)
        if let parsedDecl = dict.parsedDeclaration {
            // Always use parsed for extensions - compiler is for extended type
            if (kind?.isSwiftExtension ?? false) ||
                // Use parsed if compiler is missing (impossible?)
                compilerDecl == nil ||
                // Use parsed if it's multi-line _except_ vars where we want the { get } form
                (parsedDecl.contains("\n") && !(kind?.isSwiftProperty ?? false)) {
                neatParsedDecl = parse(parsedDecl: parsedDecl)
            }
            // Not working around SR-2608 (= default) or SR-6321 (type attrs) --- too old
        }

        guard let bestDeclaration = (neatParsedDecl ?? compilerDecl).flatMap({ format(declaration: $0 )}) else {
            let name = dict.name ?? "(unknown)"
            logDebug("Couldn't figure out a declaration for '\(name)'.")
            return nil
        }

        // Sort out decl attributes and @available statements

        availability = [] // no more early exits
        if let attributeDicts = dict.attributes {
            let allAttributes: [String]
            if let file = file {
                allAttributes = parseAttributes(dicts: attributeDicts, from: file)
            } else {
                allAttributes = parseAttributes(annotatedDecl: annotatedDecl, docDecl: dict.docDeclaration)
            }
            let (availables, others) = allAttributes.splitPartition { $0.hasPrefix("@available") }
            attributes = others
            parse(availables: availables)
        }

        // Sort out decl pieces

        let pieces: [DeclarationPiece]

        if let name = dict.name,
            let kind = kind,
            let compilerDecl = compilerDecl {
            pieces = parseToPieces(declaration: compilerDecl, name: name, kind: kind)
        } else {
            pieces = [DeclarationPiece(bestDeclaration)]
        }

        // Declaration-adjacent info
        let inheritedTypes = dict.inheritedTypes
            .flatMap { $0.compactMap { $0.name } } ?? []

        // Tidy up
        let deprecation = deprecations.isEmpty ? nil : deprecations.joined(by: "\n\n")
        let unavailable = unavailables.isEmpty ? nil : unavailables.joined(by: "\n\n")

        if availabilityRules.ignoreAttr {
            availability = []
        }
        availability = availabilityRules.defaults + availability

        return SwiftDeclaration(declaration: (attributes + [bestDeclaration]).joined(separator: "\n"),
                                deprecation: deprecation,
                                deprecatedEverywhere: deprecatedEverywhere,
                                unavailability: unavailable,
                                availability: availability,
                                namePieces: pieces,
                                typeModuleName: dict.moduleName,
                                inheritedTypes: inheritedTypes,
                                isOverride: dict.overrides != nil,
                                isSPI: attributes.contains(where: { $0.contains("@_spi") }))
    }

    private func repair(annotatedDecl decl: String) -> String {
        decl.re_sub("<syntaxtype.attribute.name>@_spi</syntaxtype.attribute.name>.*?(?=\\s|<)",
                    with: "<syntaxtype.attribute.builtin>$0</syntaxtype.attribute.builtin>")
    }

    /// Get the compiler declaration out of an 'annotated declaration' xml.
    /// Parse the XML and knock out the declaration attributes.
    func parse(annotatedDecl: String) -> String? {
        guard let rootElement = XMLHash.parseToRootElement(repair(annotatedDecl: annotatedDecl)) else {
            return nil
        }

        rootElement.children = rootElement.children.filter { content in
            guard let xmlChild = content as? SWXMLHash.XMLElement else {
                return true // keep text
            }
            return xmlChild.name != "syntaxtype.attribute.builtin"
        }
        let flat = rootElement.recursiveText.trimmingCharacters(in: .whitespaces)

        // For a nested type, ocurrences of its own name in the declaration get spelt
        // by the compiler as the fully-qualfied name.  We don't want this because we
        // will always present the type in context.
        let namePattern = nameComponents
            .map { $0.re_escapedPattern }
            .joined(separator: #"(?:<.*?>)?\."#)
        let unqualified = nameComponents.last.flatMap { flat.re_sub(namePattern, with: $0) } ?? flat

        return unqualified
            .replacingOccurrences(of: " {\n  get\n  }", with: "") // SR-9816 (not fixed as of Swift 5.1.3)
            .re_sub(#"mutating\s+mutating"#, with: "mutating") // SR-12139 (new in Swift 5.2)
    }

    /// The parsed decl is of entire lines of code, which means we may get a leading @attr if the
    /// user has written that way.  Strip it out and unindent any following lines for alignment.
    func parse(parsedDecl: String) -> String {
        let attr_re = attributeRegexp(attrPattern: #"\w+"#)
        let decl_re = #"^((?:\#(attr_re)\s*)*)(.*)$"#

        guard let matches = parsedDecl.re_match(decl_re, options: .s) else {
            return parsedDecl
        }
        let attrUnindent = String(repeating: " ", count: matches[1].count)
        return matches[2].re_sub("^\(attrUnindent)", with: "", options: .m)
    }

    /// Grab all the attributes from the associated file.
    ///
    /// SourceKit has a wild view of what counts as an "attribute" so have to check the @ manually.
    ///
    /// @available attributes that state multiple facts get reflected multiple times so we have to dedup with `Set`.
    ///
    /// Despite all this nonsense this is the preferred way of getting the attributes.  If we don't have the File,
    /// ie. we are importing, then we fall back to `parseAttributes(annotatedDecl:docDecl:)`.
    func parseAttributes(dicts: [SourceKittenDict], from file: File) -> [String] {
        struct Attr: Hashable {
            let offset: Int
            let length: Int
        }
        let attrs = dicts.compactMap { dict -> Attr? in
            guard let offset = dict.offset,
                let length = dict.length else {
                return nil
            }
            return Attr(offset: offset, length: length)
        }

        // ..and we need to keep the output stable so re-sort them again.
        let sorted = Set<Attr>(attrs).sorted { a, b in a.offset < b.offset }
        return sorted.compactMap { attr -> String? in
            let byteRange = ByteRange(location: ByteCount(attr.offset),
                                      length: ByteCount(attr.length))
            guard let text = file.stringView.substringWithByteRange(byteRange),
                text.hasPrefix("@") else {
                return nil
            }

            // We drop @objc if we've generated the ObjC version of the declaration
            if stripObjC && text.hasPrefix("@objc") {
                return nil
            }

            return text
        }
    }

    /// Grab the attributes by reverse-engineering the various SourceKit formats.
    ///
    /// This is not preferred because the Swift compiler has random policies about what
    /// attributes go where if at all.
    func parseAttributes(annotatedDecl: String, docDecl: String?) -> [String] {
        var attrs = [String]()
        if let rootElement = XMLHash.parseToRootElement(annotatedDecl) {
            let flatDecl = rootElement.recursiveText
            attrs += flatDecl.swiftAttributes(attrPattern: #"\w+"#)
        }
        if let docDecl = docDecl {
            attrs += docDecl.swiftAttributes(attrPattern: "available")
        }
        return attrs
    }

    /// Tidy up the declaration to fit on the screen.
    /// We could add more tweakables here, eg. drop the ACL & other attributes; ignore source formatting.
    func format(declaration: String) -> String {
        if let kind = kind {
            if kind.isSwiftBodiedType {
                return DeclPrinter.formatStructural(swift: declaration)
            }
            if kind.isGenericParameter {
                return declaration
            }
        }
        return DeclPrinter.format(swift: declaration)
    }
}

/// Regexp to match attributes.  `attrPattern` is the RE for the attribute name.
/// Probably fails with raw/multiline strings inside attributes, should SwiftSyntax I suppose...
private func attributeRegexp(attrPattern: String) -> String {
    let qstringPattern = #""(?:[^"\\]*|\\.)*""#
    return #"@\#(attrPattern)(?:\s*\((?:[^")]*|\#(qstringPattern))*\))?"#
}

private extension String {
    /// Pull out attributes from a declaration-type string.
    func swiftAttributes(attrPattern: String) -> [String] {
        let re = attributeRegexp(attrPattern: attrPattern)
        return re_matches(re).map { $0[0] }
    }
}

private extension XMLHash {
    /// Wrap up the initial parse steps and get down to the useful part of an XML parse.
    static func parseToRootElement(_ xmlText: String) -> XMLElement? {
        let xml = XMLHash.parse(xmlText)
        if case let .parsingError(error) = xml {
            // SourceKit bug
            logDebug("Couldn't parse SourceKit XML.  Error: '\(error)', xml: '\(xmlText)'.")
            return nil
        }
        guard let rootIndexer = xml.children.first,
            case let .element(rootElement) = rootIndexer,
            !rootElement.innerXML.isEmpty else {
            // SourceKit bug, probably
            logDebug("Malformed SourceKit XML from '\(xmlText)'.")
            return nil
        }
        return rootElement
    }
}

/// An adapter to build Swift declaration info from the pieces we may have got from an ObjC build.
final class ObjCSwiftDeclarationBuilder : SwiftDeclarationBuilder {
    /// Take ObjC info, and form enough pieces of Swift info to drive the declaration builder
    init(objCDict: SourceKittenDict, kind: DefKind, availability: Gather.Availability) {
        var swiftDict = SourceKittenDict()
        let swiftDecl = objCDict.swiftDeclaration
        if let swiftDecl = swiftDecl {
            swiftDict[SwiftDocKey2.fullyAnnotatedDecl.rawValue] = "<objc>\(swiftDecl.htmlEscaped)</objc>"
        }
        if let swiftName = objCDict.swiftName {
            swiftDict[SwiftDocKey.name.rawValue] = swiftName
        }
        precondition(!kind.isSwift)
        let swiftKind = kind.otherLanguageKind(otherLanguageDecl: swiftDecl)
        super.init(dict: swiftDict,
                   nameComponents: [],
                   file: nil,
                   kind: swiftKind,
                   stripObjC: false,
                   availabilityRules: availability)
    }
}
