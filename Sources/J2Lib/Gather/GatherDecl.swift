//
//  GatherDecl.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

// Swift declaration production.
// 1) make a nice-looking declaration
// 2) extract and analyze @available attributes
// 3) generate name declarations
// 4) identify generic parameter names to avoid autolinking them
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
//
// Strategy:
// 1) Get attributes directly from sourcekit data.
// 2) Get compiler declaration from fully_annotated_decl:
//    - strip out attribute elements
//    - convert to text
// 3) Check parsed declaration to see if we prefer it
//    - means newlines.  should really just bash out a naive prettyprinter.
//    - strip leading attributes and unindent
// 4) Do @available empire
// 5) Form decl stacking attributes on decl
// 6) Form prettyname and pick out generic params by xml-parsing the
//    fully_annotated_decl.

public struct SwiftDeclaration {
    public let declaration: String
    public let genericParameters: [String]
    public let deprecationMessage: String?
    public let availableList: [String]
    public let prettyName: String
}

final class SwiftDeclarationBuilder {
    let dict: SourceKittenDict
    let file: SourceKittenFramework.File?

    private init(dict: SourceKittenDict, file: SourceKittenFramework.File?) {
        self.dict = dict
        self.file = file
    }

    static func build(dict: SourceKittenDict, file: SourceKittenFramework.File?) -> SwiftDeclaration? {
        SwiftDeclarationBuilder(dict: dict, file: file).build()
    }

    func build() -> SwiftDeclaration? {
        guard let annotatedDecl = dict["key.fully_annotated_decl"] as? String,
            let parsedDecl = dict["key.parsed_declaration"] as? String else { // xxx too harsh
                return nil
        }
        return SwiftDeclaration(declaration: parsedDecl,
                                genericParameters: [],
                                deprecationMessage: nil,
                                availableList: [],
                                prettyName: annotatedDecl)
    }
}
