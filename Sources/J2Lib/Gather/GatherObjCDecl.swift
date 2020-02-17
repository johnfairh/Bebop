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

        let deprecations = parseDeprecations()

        let pieces: [DeclarationPiece]

        if let name = dict[SwiftDocKey.name.rawValue] as? String {
            pieces = parseToPieces(declaration: neatDeclaration, name: name)
        } else {
            pieces = [DeclarationPiece(neatDeclaration)]
        }

        return ObjCDeclaration(declaration: neatDeclaration,
                               deprecation: deprecations.deprecated,
                               unavailability: deprecations.unavailable,
                               namePieces: pieces)
    }

    /// Tidy up the Objective-C declaration.  We need to:
    /// 1) Remove ivar declaration blocks from @interfaces
    /// 2) Remove the 'structure' part of a nominal type def (we get this with a parsed declaration)
    /// 3) Understand NS_ENUM magic
    /// 4) Remove default property attributes from property decls
    func parse(declaration: String) -> String {
        return declaration
    }

    /// Make some sense out of the four optional attributes that SourceKitten gives us.
    func parseDeprecations() -> (deprecated: Localized<String>?, unavailable: Localized<String>?) {
        return (nil, nil)
    }

    /// Parse the cleaned-up declaration into a sequence of pieces.
    func parseToPieces(declaration: String, name: String) -> [DeclarationPiece] {
        return [DeclarationPiece(declaration)]
    }
}
