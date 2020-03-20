//
//  GatherDeclPieces.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SwiftSyntax

/// Declaration pieces.
///
/// This is about displaying definition names in contents pages in the current Apple style,
/// where the "name" parts of the definition are styled differently to the others.
///
/// So for "class Fred" we get "class _Fred_".
/// So far so good.
/// But Swift functions are a wild evolution of objc methods, so given:
/// "func ff(a: T1, b c: T2, _ d: T3)" we need to get to "func _ff_(_a_: T1, _b_: T2, T3)".
/// ...in the presence of arbitrarily-complex types and other stuff that defeat regular
/// expressions.
///
/// Intentionally dropping generic parameter lists, requirements clauses, and inheritance
/// clauses from nominal/extension type declarations.
///
extension SwiftDeclarationBuilder {
    /// Parse a swift compiler-style declaration into pieces for an index page
    func parseToPieces(declaration: String, name: String, kind: DefKind) -> [DeclarationPiece] {
        guard !kind.hasSwiftFunctionName else {
            return parseFunctionToPieces(declaration: declaration, kind: kind)
        }
        guard !kind.isSwiftEnumElement else {
            return parseEnumElementToPieces(declaration: declaration, kind: kind)
        }
        var pieces: [DeclarationPiece] = []
        if let declPrefix = kind.declPrefix {
            pieces.append(.other("\(declPrefix) "))
        }
        pieces.append(.name(name))
        // grab the type for properties but not any {get set}
        if kind.isSwiftProperty,
            let match = declaration.re_match(#"(?<=\#(name)).*?(?=$|\s*\{)"#) {
            pieces.append(.other(match[0]))
        }
        return pieces
    }

    /// Functions are incredibly difficult because the name is distributed through the declaration and regexps are very
    /// tricky because of closure parameters!  Also some bits we want to elide.
    private func parseFunctionToPieces(declaration: String, kind: DefKind) -> [DeclarationPiece] {
        // Strip declaration of leading and trailing bits
        guard let match = declaration.re_match("(?:func|init|subscript).*?(?=$|\\s*where)"),
            case let cleanDecl = match[0].re_sub(" (?:re)?throws", with: "")
                .re_sub(#"\s*\{(?:\s*get|\s+set)+\s*\}"#, with: "") else {
            return [.other(declaration)]
        }
        return parseToPieces(cleanDecl: cleanDecl, kind: kind)
    }

    /// Enum elements are a lot like function parameters.  Luckily SwiftSyntax is aware of this and uses the exact same
    /// types to model the associated value clause.
    private func parseEnumElementToPieces(declaration: String, kind: DefKind) -> [DeclarationPiece] {
        // Strip declaration of leading and trailing bits
        guard let match = declaration.re_match("case.*?(?=$|\\s=)") else {
            return [.other(declaration)]
        }
        return parseToPieces(cleanDecl: match[0], kind: kind)
    }

    private func parseToPieces(cleanDecl: String, kind: DefKind) -> [DeclarationPiece] {
        // Build the parse tree
        guard let syntax = try? SyntaxParser.parse(source: cleanDecl) else {
            return [.other(cleanDecl)]
        }
        // Pick out and sort the tokens we want
        var visitor = FunctionPiecesVisitor(prefix: kind.declPrefix,
                                            includeFirstToken: kind.isSwiftSubscript)
        syntax.walk(&visitor)
        return visitor.pieces
    }
}

/// SwiftSyntax visitor to pick out pieces of a function/enum element's name (the token after the
/// `func`, then the names of any arguments, picking whichever looks right.  Also discard
/// extraneous stuff from the declaration: default argument values, type attributes.
private class FunctionPiecesVisitor: SyntaxVisitor {
    private var ignoreNextToken: Bool
    private var seenName: Bool
    /// Accumulate non-name piece
    private var current: String
    /// Generated output
    internal private(set) var pieces: [DeclarationPiece]

    init(prefix: String?, includeFirstToken: Bool) {
        if let prefix = prefix {
            pieces = [.other("\(prefix) ")]
            ignoreNextToken = !includeFirstToken
        } else {
            pieces = []
            ignoreNextToken = false // subscript/init where name==keyword, don't swallow
        }
        seenName = false
        current = ""
    }

    /// A non-name token - accumulate
    func addOther(_ token: String?, trim: Bool = false) {
        if var token = token {
            if trim {
                token = token.trimmingTrailingCharacters(in: .whitespaces)
            }
            current.append(token)
        }
    }

    /// Helper - terminate current accumulator
    func finishCurrentOther() {
        if !current.isEmpty {
            pieces.append(.other(current))
            current = ""
        }
    }

    /// A name token
    func addName(_ name: String) {
        finishCurrentOther()
        pieces.append(.name(name.trimmingTrailingCharacters(in: .whitespaces)))
    }

    /// Token - either `func`, the initial identifier, or some non-name stuff
    func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        if ignoreNextToken {
            ignoreNextToken = false
        } else if !seenName {
            seenName = true
            addName(token.description)
        } else {
            addOther(token.description)
        }
        return .skipChildren
    }

    /// A parameter - don't descend, figure out what parts we want and feed them directly
    func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        if let firstName = node.firstName {
            if firstName.text != "_" {
                addName(firstName.description)
                addOther(node.colon?.description)
            }
        }
        // drop type attributes (@escaping etc)
        addOther(node.type?.description.re_sub("@\\w+ ", with: ""), trim: true) // skipping default args
        addOther(node.ellipsis?.description)
        addOther(node.trailingComma?.description)
        return .skipChildren
    }

    /// Called at the end of everything, finish our current accumulator
    func visitPost(_ node: CodeBlockItemSyntax) {
        finishCurrentOther()
    }
}
