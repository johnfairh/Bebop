//
//  GatherObjCDecl.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

// Objective-C declaration production.
//
// 1) make a nice-looking declaration
// 2) consolidate deprecation / unavailable info
// 3) generate piece-name declarations
//
// This is thankfully easier than the Swift version because the
// degrees of freedom are far far less.

/// Short-lived workspace for figuring things out about an ObjC declaration
class ObjCDeclarationBuilder {
    let dict: SourceKittenDict
    let kind: DefKind

    init(dict: SourceKittenDict, kind: DefKind) {
        self.dict = dict
        self.kind = kind
    }

    func build() -> ObjCDeclaration? {
        /// This thing is either the parsed declaration or the libclang round-tripped version.
        /// If there's no doc comment we get the parsed one, otherwise libclang.
        guard let declaration = dict[SwiftDocKey.parsedDeclaration.rawValue] as? String else {
            logDebug("No declaration found in ObjC def, ignoring \(dict).")
            return nil
        }
        let neatDeclaration = parse(declaration: declaration)
        let pieces: [DeclarationPiece]

        // If we're missing the name then don't try very hard
        if let name = dict[SwiftDocKey.name.rawValue] as? String {
            pieces = parseToPieces(declaration: neatDeclaration, name: name)
        } else {
            pieces = [DeclarationPiece(neatDeclaration)]
        }

        let deprecations = parseDeprecations()

        return ObjCDeclaration(declaration: neatDeclaration,
                               deprecation: deprecations.deprecated,
                               unavailability: deprecations.unavailable,
                               namePieces: pieces)
    }

    /// Tidy up the Objective-C declaration to remove stuff that libclang has added
    /// but humans aren't interested in and work around bugs in the stack.
    func parse(declaration input: String) -> String {
        var decl = input
        if kind.isObjCStructural {
            // Strip trailing content that can show up: ivar blocks, random {}, etc.
            decl = decl.re_sub(#"(?:\s*)[{\n].*\z"#, with: "", options: [.s])
        } else if kind.isObjCTypedef {
            // Bug somewhere stripping the last char of NS_ENUM typedefs
            if decl.re_isMatch(#"^typedef\s+NS_\w*\("#) && !decl.hasSuffix(")") {
                decl.append(")")
            }
        } else if kind.isObjCProperty {
            if let propertyMatch = decl.re_match(#"@property\s*( \(.*?\))"#) {
                // 1) Don't show atomic: it's the default
                // 2) Don't show readwrite: it's the default
                // 3) Don't show 'assign': that's a default
                // 3a) Don't show 'assign, unsafe_unretained': that's the same default in Xcode11.4+
                var newProperties = propertyMatch[1].re_sub(#"\b(?:atomic|readwrite|assign|unsafe_retained),? ?"#, with: "")
                if newProperties == " ()" {
                    newProperties = "" // all gone!
                }
                decl = decl.re_sub(#"(?<=@property)\s+\(.*?\)"#, with: newProperties)
            }
        }
        // Strip any trailing semicolons/whitespace - inconsistencies somewhere
        return decl.re_sub(#"[;\s]*$"#, with: "")
    }

    /// Make some sense out of the four optional attributes that SourceKitten gives us.
    func parseDeprecations() -> (deprecated: Localized<String>?, unavailable: Localized<String>?) {
        return (nil, nil)
    }

    /// Parse the cleaned-up declaration into a sequence of pieces.
    func parseToPieces(declaration: String, name: String) -> [DeclarationPiece] {
        // type: <typekindname> name
        //
        // DefKind(o: .category,       "Category",         s: .extension,              dash: "Extension", meta: .extension),
        // DefKind(o: .class,          "Class",            s: .class,                                     meta: .type),
        // DefKind(o: .protocol,       "Protocol",         s: .protocol,                                  meta: .type),
        // DefKind(o: .struct,         "Structure",        s: .struct,                 dash: "Struct",    meta: .type),
        // DefKind(o: .enum,           "Enumeration",      s: .enum, /* or struct */   dash: "Enum",      meta: .type),
        // DefKind(o: .typedef,        "Type Definition",  s: .typealias,              dash: "Type",      meta: .type),
        //
        // enumcase like this too, but blank prefix
        //
        // DefKind(o: .enumcase,       "Enumeration Case", s: .enumelement,            dash: "Case"),

        // variable: strip any @property(stuff)|extern / before the name / name / stop
        //
        // DefKind(o: .constant,       "Constant",         s: .varGlobal,                                 meta: .variable),
        // DefKind(o: .property,       "Property",         s: .varInstance), /* or varClass */
        // DefKind(o: .field,          "Field",            s: .varInstance),
        // DefKind(o: .ivar,           "Instance Variable",                            dash: "Variable"),

        // function-like: tremendous fun
        // DefKind(o: .initializer,    "Initializer",      s: .functionConstructor),
        // DefKind(o: .methodClass,    "Class Method",     s: .functionMethodClass,    dash: "Method"),
        // DefKind(o: .methodInstance, "Instance Method",  s: .functionMethodInstance, dash: "Method"),
        // DefKind(o: .function,       "Function",         s: .functionFree,                              meta: .function),

        // other: all-name, sure....
        // DefKind(o: .unexposedDecl,  "Unexposed"),
        // DefKind(o: .mark,           "Mark"),
        // DefKind(o: .moduleImport,   "Module"),

        return [DeclarationPiece(declaration)]
    }
}
