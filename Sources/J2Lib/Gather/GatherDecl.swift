//
//  GatherDecl.swift
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
// 5) Swift decls generated from ObjC code have lost their metadata by the time
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
// 4) Do @available empire - parse manually, SwiftSyntax too bespoke
// 5) Form decl stacking attributes on decl
// 6) Form name pieces by invoking SwiftSyntax.
//    This is the only option because we don't have decl XML for the ObjC
//    ones.

public struct SwiftDeclaration {
    public let declaration: String
    public let deprecations: [String]
    public let availability: [String]
    public let namePieces: [Piece]

    public enum Piece {
        case name(String)
        case other(String)
    }
}

final class SwiftDeclarationBuilder {
    let dict: SourceKittenDict
    let file: File?
    let kind: DefKind?

    var compilerDecl: String?
    var neatParsedDecl: String?
    var attributes: [String] = []
    var deprecations: [String] = []
    var obsoletions: [String] = []
    var availability: [String] = []

    init(dict: SourceKittenDict, file: File?, kind: DefKind?) {
        self.dict = dict
        self.file = file
        self.kind = kind
    }

    func build() -> SwiftDeclaration? {
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
        }

        guard let bestDeclaration = neatParsedDecl ?? compilerDecl else {
            let name = dict[SwiftDocKey.name.rawValue] as? String ?? "(unknown)"
            logDebug("Couldn't figure out a declaration for '\(name)'.")
            return nil
        }

        if let attributeDicts = dict["key.attributes"] as? [SourceKittenDict] {
            var allAttributes = parse(attributeDicts: attributeDicts)
            let pivot = allAttributes.partition { $0.hasPrefix("@available") }
            attributes = Array(allAttributes[0..<pivot])

            parse(availables: Array(allAttributes[pivot...]))
        }

        return SwiftDeclaration(declaration: (attributes + [bestDeclaration]).joined(separator: "\n"),
                                deprecations: deprecations,
                                availability: availability,
                                namePieces: [])
    }

    /// Get the compiler declaration out of an 'annotated declaration' xml.
    /// Parse the XML and knock out the declaration attributes.
    func parse(annotatedDecl: String) -> String? {
        let xml = SWXMLHash.parse(annotatedDecl)
        if case let .parsingError(error) = xml {
            // SourceKit bug
            logWarning("Couldn't parse SourceKit XML.  Error: '\(error)', xml: '\(annotatedDecl)'.")
            return nil
        }
        guard let rootIndexer = xml.children.first,
            case let .element(rootElement) = rootIndexer else {
            // SourceKit bug, probably
            logWarning("Malformed SourceKit XML from '\(annotatedDecl)'.")
            return nil
        }

        rootElement.children = rootElement.children.filter { content in
            guard let xmlChild = content as? SWXMLHash.XMLElement else {
                return true // keep text
            }
            return xmlChild.name != "syntaxtype.attribute.builtin"
        }
        var flat = rootElement.recursiveText
        if flat.first == " " {
            flat.removeFirst()
        }

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
        return String(matches[2]).re_sub("^\(attrUnindent)", with: "", options: .m)
    }

    /// Grab all the attributes from the associated file.
    /// SourceKit has a wild view of what counts as an "attribute" so have to check the @....
    func parse(attributeDicts: [SourceKittenDict]) -> [String] {
        attributeDicts.compactMap { dict in
            guard let offset = dict["key.offset"] as? Int64,
                let length = dict["key.length"] as? Int64 else {
                return nil
            }

            let byteRange = ByteRange(location: ByteCount(offset), length: ByteCount(length))
            guard let text = file?.stringView.substringWithByteRange(byteRange),
                text.hasPrefix("@") else {
                return nil
            }

            return text
        }
    }
}
