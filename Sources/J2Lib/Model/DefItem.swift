//
//  DefItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// Base class of definition items -- those that correspond to a definition in
/// some source code.
public class DefItem: Item {
    /// Location of the definition
    public let location: DefLocation
    /// Kind of the definition
    public let defKind: DefKind
    /// Declarations
    public let swiftDeclaration: SwiftDeclaration?
    public let objCDeclaration: ObjCDeclaration?
    /// Documentation
    public private(set) var documentation: RichDefDocs
    /// Deprecation notice
    public private(set) var deprecationNotice: RichText?
    /// Unavailable notice
    public private(set) var unavailableNotice: RichText?
    /// Name in the other language
    public let otherLanguageName: String?

    /// Create from a gathered definition
    public init?(location: DefLocation, gatherDef: GatherDef, uniquer: StringUniquer) {
        guard let name = gatherDef.sourceKittenDict[SwiftDocKey.name.rawValue] as? String,
            let kind = gatherDef.kind else {
            // XXX wrn - lots to add here tho, leave for now
            logWarning("Incomplete def, ignoring -- missing name")
            return nil
        }
        let children = gatherDef.children.asDefItems(location: location, uniquer: uniquer)
        let line = (gatherDef.sourceKittenDict[SwiftDocKey.docLine.rawValue] as? Int64).flatMap(Int.init)
        let startLine = (gatherDef.sourceKittenDict[SwiftDocKey.parsedScopeStart.rawValue] as? Int64).flatMap(Int.init)
        let endLine = (gatherDef.sourceKittenDict[SwiftDocKey.parsedScopeEnd.rawValue] as? Int64).flatMap(Int.init)
        self.location = DefLocation(moduleName: location.moduleName,
                                    passIndex: location.passIndex,
                                    filePathname: location.filePathname,
                                    firstLine: startLine ?? line,
                                    lastLine: endLine ?? line)
        self.defKind = kind
        self.documentation = RichDefDocs(gatherDef.translatedDocs)

        // ObjC-Swift merge

        if (gatherDef.swiftDeclaration == nil && kind.isSwift) ||
           (gatherDef.objCDeclaration == nil && kind.isObjC) {
            // XXX wrn
            logWarning("No declaration, ignoring")
            return nil
        }
        self.swiftDeclaration = gatherDef.swiftDeclaration
        self.objCDeclaration = gatherDef.objCDeclaration

        // usr
        // type module name
        // start_line / end_line (vs line???)
        // gen_req
        // inher_types

        let deprecations = [objCDeclaration?.deprecation, swiftDeclaration?.deprecation].compactMap { $0 }
        if !deprecations.isEmpty {
            self.deprecationNotice = RichText(deprecations.joined(by: "\n\n"))
        } else {
            self.deprecationNotice = nil
        }
        self.unavailableNotice = objCDeclaration?.unavailability.flatMap(RichText.init)

        if kind.isObjC {
            otherLanguageName = gatherDef.sourceKittenDict[SwiftDocKey.swiftName.rawValue] as? String
        } else {
            otherLanguageName = nil // todo swift->objc
        }

        super.init(name: name, slug: uniquer.unique(name.slugged), children: children)
    }

    /// Used to create the `decls-json` product.
    public override func encode(to encoder: Encoder) throws {
        try doEncode(to: encoder)
    }

    /// Visitor
    public override func accept(visitor: ItemVisitorProtocol, parents: [Item]) {
        visitor.visit(defItem: self, parents: parents)
    }

    // Swift/ObjC personality

    /// Does the def have Swift + ObjC versions?
    public var dualLanguage: Bool {
        otherLanguageName != nil
    }

    /// Written language of the definition
    public var primaryLanguage: DefLanguage {
        defKind.isSwift ? .swift : .objc
    }

    /// Converted language of the definition - or `nil` if unavailable
    public var secondaryLanguage: DefLanguage? {
        dualLanguage ? primaryLanguage.otherLanguage : nil
    }

    /// Name of the def in Swift, or `nil` if unavailable
    public var swiftName: String? {
        defKind.isSwift ? name : otherLanguageName
    }

    /// Name of the def in ObjC, or `nil` if unavailable
    public var objCName: String? {
        defKind.isObjC ? name : nil
    }

    public override func title(for language: DefLanguage) -> Localized<String>? {
        switch language {
        case .swift: return swiftName.flatMap { .init(unlocalized: $0) }
        case .objc: return objCName.flatMap { .init(unlocalized: $0) }
        }
    }

    public override var kind: ItemKind { defKind.metaKind }

    public override var showInToc: ShowInToc {
        // Always show nominal types/extensions, however nested.
        // (nesting can be natural or due to custom categories.)
        if defKind.metaKind == .extension ||
            defKind.metaKind == .type {
            return .yes
        }
        // Only show functions etc. at the top level -- allows global
        // functions but suppresses members.
        return .atTopLevel
    }

    /// Format the item's associated text data
    public override func format(blockFormatter: RichText.Formatter, inlineFormatter: RichText.Formatter) rethrows {
        try documentation.format(blockFormatter)
        try topic?.format(inlineFormatter)
        try deprecationNotice?.format(blockFormatter)
    }
}
