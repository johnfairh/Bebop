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
        guard let declaration = dict.parsedDeclaration else {
            logDebug("No declaration found in ObjC def, ignoring \(dict).")
            return nil
        }
        let neatDeclaration = parse(declaration: declaration)
        let pieces: [DeclarationPiece]

        // If we're missing the name then don't try very hard
        if let name = dict.name {
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
        // Some grotty broken fixup to remove stuff that is expressed elsewhere.
        // Clang gives us simple trailing attributes but not always?
        var decl = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .re_sub(#"\s+__(deprecated|unavailable)"#, with: "")
            .re_sub(#"\s+NS_SWIFT_NAME\(.*\)"#, with: "")

        if kind.isObjCStructural {
            // Strip trailing content that can show up: ivar blocks, random {}, etc.
            decl = decl.re_sub(#"(?:\s*)[{\n].*\z"#, with: "", options: [.s])
        } else if kind.isObjCTypedef {
            // Bug somewhere stripping the last char of NS_ENUM typedefs
            if decl.re_isMatch(#"^typedef\s+NS_\w*\("#) && !decl.hasSuffix(")") {
                decl.append(")")
            }
        } else if kind.isObjCProperty {
            if let propertyMatch = decl.re_match(#"@property\s+\((.*?)\)"#) {
                // 1) Don't show atomic: it's the default
                // 2) Don't show readwrite: it's the default
                // 3) Don't show 'assign': that's a default
                // 3a) Don't show 'assign, unsafe_unretained': that's the same default in Xcode11.4+
                //
                // Finally undo clang multi-line formatting that is only necessary because
                // it has printed all this mess.
                let badProperties = ["atomic", "readwrite", "assign", "unsafe_unretained"]

                let newProperties = propertyMatch[1].split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !badProperties.contains($0) }
                    .joined(separator: ", ")
                let newPropertyList = newProperties.count > 0 ? " (\(newProperties))" : ""
                decl = decl
                    .re_sub(#"(?<=@property)\s+\(.*?\)"#, with: newPropertyList)
                    .re_sub(#"\s+"#, with: " ")
            }
        }
        // Strip any trailing semicolons/whitespace - inconsistencies somewhere
        return decl.re_sub(#"[;\s]*$"#, with: "")
    }

    /// Make some sense out of the four optional attributes that SourceKitten gives us.
    func parseDeprecations() -> (deprecated: Localized<String>?, unavailable: Localized<String>?) {
        func parse(_ type: L10n.Output, always: SwiftDocKey, message: SwiftDocKey) -> Localized<String>? {
            guard let always = dict[always.rawValue] as? Bool, always else {
                return nil
            }
            let output = Localized<String>.localizedOutput(type)
            guard let message = dict[message.rawValue] as? String else {
                return output
            }
            return output + " \(message)"
        }

        return (parse(.deprecated, always: .alwaysDeprecated, message: .deprecationMessage),
                parse(.unavailable, always: .alwaysUnavailable, message: .unavailableMessage))
    }

    /// Parse the cleaned-up declaration into a sequence of pieces, removing extraneous stuff,
    /// for an item title.  The full declaration is preserved elsewhere.
    func parseToPieces(declaration clangDecl: String, name: String) -> [DeclarationPiece] {
        // Undo clang multi-line formatting.
        // Drop nullability specifiers from this view
        let declaration = clangDecl
            .re_sub(#"\s+"#, with: " ")
            .re_sub(#"\s*(_?_Nullable|_?_Nonnull|_?_Null_unspecified)\b"#, with: "", options: .i)
            .re_sub(#"\b(nullable|nonnull|null_unspecified)\s+"#, with: "")

        // type: <typekindname> name
        //
        // DefKind(o: .category,
        // DefKind(o: .class,
        // DefKind(o: .protocol,
        // DefKind(o: .struct,
        // DefKind(o: .enum,
        // DefKind(o: .typedef,
        // DefKind(o: .enumcase,
        if let declPrefix = kind.declPrefix {
            return [.other("\(declPrefix) "), .name(name)]
        }
        // ObjCMethod-like: sigh...
        // DefKind(o: .initializer,
        // DefKind(o: .methodClass,
        // DefKind(o: .methodInstance,
        if kind.isObjCMethod {
            return parseMethodToPieces(method: declaration)
        }
        // variable: strip any @property(stuff)|extern / before the name / name / stop
        //
        // DefKind(o: .constant,
        // DefKind(o: .property,
        // DefKind(o: .propertyClass,
        // DefKind(o: .field,
        // DefKind(o: .ivar,
        if kind.isObjCVariable {
            guard let matches = declaration.re_match(#"(^.*)\#(name)"#) else {
                return [.name(declaration)]
            }
            let prefix = matches[1].re_sub(#"^(extern|@property\s*(?:\(.*?\))?)"#, with: "")
            return [.other(prefix.re_sub(#"^\s+"#, with: "")), .name(name)]
        }
        // Free C function: don't try to decode types
        // DefKind(o: .function,
        if kind.isObjCCFunction {
            guard let matches = declaration.re_match(#"(^.*)\#(name)(.*$)"#, options: [.s]) else {
                return [.name(declaration)]
            }
            return [.other(matches[1]), .name(name), .other(matches[2])]
        }
        // Won't make it anywhere we can see it
        //
        // DefKind(o: .unexposedDecl,  "Unexposed"),
        // DefKind(o: .mark,           "Mark"),
        // DefKind(o: .moduleImport,   "Module"),
        return [.name(declaration)]
    }

    /// Deal with the method syntax, pull out the 'name' pieces.
    private func parseMethodToPieces(method: String) -> [DeclarationPiece] {
        var pieces = [DeclarationPiece]()

        var decl = method
        // Very grotty ad-hoc cleanup - maybe there is something in libclang
        // to help parse out just the core pieces..
        [#"\s+OBJC_DESIGNATED_INITIALIZER\b"#,
         #"\s+SWIFT_.*\b"#].forEach {
            decl = decl.re_sub($0, with: "", options: .i)
        }

        guard let intro = decl.prefixMatch(#".*?(?=\w+\s*($|:))"#) else {
            return [.name(method)] // confused
        }
        pieces.append(.other(intro))
        while true {
            guard let name = decl.prefixMatch(#"\w+"#) else {
                return [.name(method)] // confused again
            }
            pieces.append(.name(name))
            guard let nextOther = decl.prefixMatch(#"\s*:.*?(?=\w+\s*:)"#) else {
                pieces.append(.other(decl))
                break
            }
            pieces.append(.other(nextOther))
        }
        return pieces
    }
}

private extension String {
    mutating func prefixMatch(_ pattern: String) -> String? {
        guard let match = self.re_match("^\(pattern)", options: [.s]) else {
            return nil
        }
        let prefix = match[0]
        self = String(dropFirst(prefix.count))
        return prefix
    }
}

/// An adapter to build ObjC declaration info from the pieces we may have got from a Swift build
final class SwiftObjCDeclarationBuilder : ObjCDeclarationBuilder {
    /// Try to build the ObjC version of an @objc Swift decl
    init?(dict: inout SourceKittenDict, kind: DefKind) {
        guard let usr = dict.usr,
            !kind.isSwiftExtension,
            let objcKind = kind.otherLanguageKind,
            let info = GatherSwiftToObjC.current?.usrToInfo[usr] else {
            return nil
        }

        dict[.objcName] = info.name // ahem

        var objcDict = SourceKittenDict()
        objcDict[.parsedDeclaration] = info.declaration
        objcDict[.name] = info.name

        super.init(dict: objcDict, kind: objcKind)
    }
}
