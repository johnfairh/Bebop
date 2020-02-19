//
//  GatherSwiftDecl.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
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
    let file: File?
    let kind: DefKind?
    let availabilityRules: GatherAvailabilityRules

    var compilerDecl: String?
    var neatParsedDecl: String?
    var attributes: [String] = []
    var deprecations: [Localized<String>] = []
    var availability: [String] = []

    init(dict: SourceKittenDict, file: File?, kind: DefKind?, availabilityRules: GatherAvailabilityRules) {
        self.dict = dict
        self.file = file
        self.kind = kind
        self.availabilityRules = availabilityRules
    }

    func build() -> SwiftDeclaration? {
        availability = availabilityRules.defaults // override later if we get that far

        guard let annotatedDecl = dict["key.fully_annotated_decl"] as? String else {
            // Means unavailable or something, not an error condition
            return nil
        }

        compilerDecl = parse(annotatedDecl: annotatedDecl)
        if let parsedDecl = dict[SwiftDocKey.parsedDeclaration.rawValue] as? String {
            // Always use parsed for extensions - compiler is for extended type
            if (kind?.isSwiftExtension ?? false) ||
                // Use parsed if compiler is missing (impossible?)
                compilerDecl == nil ||
                // Use parsed if it's multi-line _except_ vars where we want the { get} form
                (parsedDecl.contains("\n") && !(kind?.isSwiftProperty ?? false)) {
                neatParsedDecl = parse(parsedDecl: parsedDecl)
            }
            // Not working around SR-2608 (= default) or SR-6321 (type attrs) --- too old
        }

        guard let bestDeclaration = neatParsedDecl ?? compilerDecl else {
            let name = dict[SwiftDocKey.name.rawValue] as? String ?? "(unknown)"
            logDebug("Couldn't figure out a declaration for '\(name)'.")
            return nil
        }

        // Sort out decl attributes and @available statements

        if let attributeDicts = dict["key.attributes"] as? [SourceKittenDict] {
            var allAttributes = parse(attributeDicts: attributeDicts)
            let pivot = allAttributes.partition { $0.hasPrefix("@available") }
            attributes = Array(allAttributes[0..<pivot])

            parse(availables: Array(allAttributes[pivot...]))
        }

        // Sort out decl pieces

        let pieces: [DeclarationPiece]

        if let name = dict[SwiftDocKey.name.rawValue] as? String,
            let kind = kind,
            let compilerDecl = compilerDecl {
            pieces = parseToPieces(declaration: compilerDecl, name: name, kind: kind)
        } else {
            pieces = [DeclarationPiece(bestDeclaration)]
        }

        // Tidy up
        let deprecation = deprecations.isEmpty ? nil : deprecations.joined(by: "\n\n")

        if availabilityRules.ignoreAttr {
            availability = []
        }
        availability = availabilityRules.defaults + availability

        return SwiftDeclaration(declaration: (attributes + [bestDeclaration]).joined(separator: "\n"),
                                deprecation: deprecation,
                                availability: availability,
                                namePieces: pieces)
    }

    /// Get the compiler declaration out of an 'annotated declaration' xml.
    /// Parse the XML and knock out the declaration attributes.
    func parse(annotatedDecl: String) -> String? {
        let xml = SWXMLHash.parse(annotatedDecl)
        if case let .parsingError(error) = xml {
            // SourceKit bug
            logDebug("Couldn't parse SourceKit XML.  Error: '\(error)', xml: '\(annotatedDecl)'.")
            return nil
        }
        guard let rootIndexer = xml.children.first,
            case let .element(rootElement) = rootIndexer else {
            // SourceKit bug, probably
            logDebug("Malformed SourceKit XML from '\(annotatedDecl)'.")
            return nil
        }

        rootElement.children = rootElement.children.filter { content in
            guard let xmlChild = content as? SWXMLHash.XMLElement else {
                return true // keep text
            }
            return xmlChild.name != "syntaxtype.attribute.builtin"
        }
        let flat = rootElement.recursiveText.trimmingCharacters(in: .whitespaces)

        // XXX todo - unqualified name massaging, need parent hierarchy

        // Workaround for SR-9816 (not fixed as of Swift 5.1.3)
        return flat.replacingOccurrences(of: " {\n  get\n  }", with: "")
    }

    /// The parsed decl is of entire lines of code, which means we may get a leading @attr if the
    /// user has written that way.  Strip it out and unindent any following lines for alignment.
    func parse(parsedDecl: String) -> String {
        let qstring_re = #""(?:[^"\\]*|\\.)*""#
        let attr_re = #"@\w+(?:\s*\((?:[^")]*|\#(qstring_re))*\))?"#
        let decl_re = #"^((?:\#(attr_re)\s*)*)(.*)$"#

        guard let matches = parsedDecl.re_match(decl_re, options: .s) else {
            return parsedDecl
        }
        let attrUnindent = String(repeating: " ", count: matches[1].count)
        return matches[2].re_sub("^\(attrUnindent)", with: "", options: .m)
    }

    /// Grab all the attributes from the associated file.
    /// SourceKit has a wild view of what counts as an "attribute" so have to check the @
    /// @available attributes that state multiple facts get reflected multiple times so we have to dedup.
    func parse(attributeDicts: [SourceKittenDict]) -> [String] {
        struct Attr: Hashable {
            let offset: Int64
            let length: Int64
        }
        let attrs = attributeDicts.compactMap { dict -> Attr? in
            guard let offset = dict["key.offset"] as? Int64,
                let length = dict["key.length"] as? Int64 else {
                return nil
            }
            return Attr(offset: offset, length: length)
        }

        // ..and we need to keep the output stable so re-sort them again.
        let sorted = Set<Attr>(attrs).sorted { a, b in a.offset < b.offset }
        return sorted.compactMap { attr -> String? in
            let byteRange = ByteRange(location: ByteCount(attr.offset),
                                      length: ByteCount(attr.length))
            guard let text = file?.stringView.substringWithByteRange(byteRange),
                text.hasPrefix("@") else {
                return nil
            }

            return text
        }
    }
}

/// An adapter to build Swift declaration info from the pieces we may have got from an ObjC build.
final class ObjCSwiftDeclarationBuilder : SwiftDeclarationBuilder {
    /// Take ObjC info, and form enough pieces of Swift info to drive the declaration builder
    init(objCDict: SourceKittenDict, kind: DefKind, availabilityRules: GatherAvailabilityRules) {
        var swiftDict = SourceKittenDict()
        let swiftDecl = objCDict[SwiftDocKey.swiftDeclaration.rawValue] as? String
        if let swiftDecl = swiftDecl {
            swiftDict["key.fully_annotated_decl"] = "<objc>\(swiftDecl)</objc>"
        }
        if let swiftName = objCDict[SwiftDocKey.swiftName.rawValue] as? String {
            swiftDict[SwiftDocKey.name.rawValue] = swiftName
        }
        precondition(!kind.isSwift)
        var swiftKind = kind.otherLanguageKind
        if let decl = swiftDecl {
            // Enums are imported as structs without NS_ENUM magic...
            if decl.hasPrefix("struct") {
                swiftKind = DefKind.from(key: SwiftDeclarationKind.struct.rawValue)!
            }
            // Properties can map to class vars...
            else if decl.contains("class var") {
                swiftKind = DefKind.from(key: SwiftDeclarationKind.varClass.rawValue)!
            }
        }
        super.init(dict: swiftDict, file: nil, kind: swiftKind, availabilityRules: availabilityRules)
    }
}
