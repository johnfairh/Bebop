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
public class DefItem: Item, CustomStringConvertible {
    /// Location of the definition
    public let location: DefLocation
    /// Kind of the definition
    public let defKind: DefKind
    /// USR
    public let usr: USR
    /// ACL
    public let acl: DefAcl
    /// Documentation
    public internal(set) var documentation: RichDefDocs
    /// Declarations
    public private(set) var swiftDeclaration: SwiftDeclaration?
    public private(set) var objCDeclaration: ObjCDeclaration?
    /// Deprecation notice
    public private(set) var deprecationNotice: RichText?
    /// Unavailable notice
    public private(set) var unavailableNotice: RichText?
    /// Name in the other language
    public let otherLanguageName: String?
    /// Names of generic type parameters
    public let genericTypeParameters: [String]
    /// Extensions on a base type - carried temporarily here and eventually merged
    public internal(set) var extensions: DefItemList
    /// Notes to add to the declaration, added during merge and resolved during format
    public private(set) var declNotes: Set<DeclNote>
    public private(set) var declNotesNotice: RichText?

    /// Create from a gathered definition
    public init?(location: DefLocation, gatherDef: GatherDef, uniquer: StringUniquer) {
        // Filter out defs we don't/can't include in docs

        guard let usr = gatherDef.sourceKittenDict.usr else {
            if let typename = gatherDef.sourceKittenDict.typeName,
                typename.contains("<<error-type>>") {
                logWarning(.localized(.wrnErrorType, gatherDef.sourceKittenDict, location))
                Stats.inc(.importFailureNoType)
            } else {
                // Usr is special, missing means just not compiled, #if'd out - should be in another pass.
                // Compiler errors come in here too unfortunately and we can't tell them apart -- the
                // key.diagnostic is useless.
                logDebug("No usr, ignoring \(gatherDef.sourceKittenDict) \(location)")
                Stats.inc(.importFailureNoUsr)
            }
            return nil
        }

        guard let name = gatherDef.sourceKittenDict.name,
            let kind = gatherDef.kind,
            ( (kind.isSwift && gatherDef.swiftDeclaration != nil) ||
              (kind.isObjC && gatherDef.objCDeclaration != nil) ) else {
            logWarning(.localized(.wrnSktnIncomplete, gatherDef.sourceKittenDict, location))
            Stats.inc(.importFailureIncomplete)
            return nil
        }

        guard kind.includeInDocs else {
            logDebug("Kind marked for exclusion, ignoring \(gatherDef.sourceKittenDict) \(location)")
            Stats.inc(.importExcluded)
            return nil
        }

        // Populate self

        let line = gatherDef.sourceKittenDict.docLine
        let startLine = gatherDef.sourceKittenDict.parsedScopeStart
        let endLine = gatherDef.sourceKittenDict.parsedScopeEnd
        self.location = DefLocation(moduleName: location.moduleName,
                                    passIndex: location.passIndex,
                                    filePathname: location.filePathname,
                                    firstLine: startLine ?? line,
                                    lastLine: endLine ?? line)
        self.defKind = kind
        self.usr = USR(usr)
        self.documentation = RichDefDocs(gatherDef.translatedDocs)
        self.swiftDeclaration = gatherDef.swiftDeclaration
        self.objCDeclaration = gatherDef.objCDeclaration

        let deprecations = [objCDeclaration?.deprecation,
                            swiftDeclaration?.deprecation].compactMap { $0 }
        if !deprecations.isEmpty {
            self.deprecationNotice = RichText(deprecations.joined(by: "\n\n"))
        } else {
            self.deprecationNotice = nil
        }
        self.unavailableNotice = objCDeclaration?.unavailability.flatMap(RichText.init)

        if kind.isObjC {
            otherLanguageName = gatherDef.sourceKittenDict.swiftName
            acl = DefAcl.forObjC
        } else {
            otherLanguageName = nil // todo swift->objc
            acl = DefAcl(name: name, dict: gatherDef.sourceKittenDict)
        }

        // Sort out children.
        // - Generic type params need to be pulled into us for reference later; we don't
        //   want them in docs.
        // - libclang generates bad children for typedefs when using code like
        //   `typedef struct Foo { ... } Foo;` and we don't want any of them.
        let children: [DefItem]
        if !kind.isObjCTypedef {
            children = gatherDef.children.asDefItems(location: location, uniquer: uniquer)
        } else {
            children = []
        }
        let (genericParams, realChildren) = children.splitPartition { $0.defKind.isGenericParameter }
        self.genericTypeParameters = genericParams.map { $0.name }
        self.extensions = []
        self.declNotes = []
        self.declNotesNotice = nil

        super.init(name: name, slug: uniquer.unique(name.slugged), children: realChildren)
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
        try unavailableNotice?.format(blockFormatter)
        try declNotesNotice?.format(blockFormatter)
    }

    /// Format the item's associated declarations
    public func formatDeclarations(formatter: RichDeclaration.Formatter) rethrows {
        try swiftDeclaration?.declaration.format(formatter)
        try objCDeclaration?.declaration.format(formatter)
    }

    public var swiftGenericRequirements: String? {
        swiftDeclaration?.genericRequirements
    }

    /// Is this a constrained Swift extension?
    public var isSwiftExtensionWithConstraints: Bool {
        defKind.isSwiftExtension && swiftGenericRequirements != nil
    }

    /// Is this a Swift extension that adds protocol conformances?
    public var isSwiftExtensionWithConformances: Bool {
        return swiftDeclaration.flatMap {
            defKind.isSwiftExtension && !$0.inheritedTypes.isEmpty
        } ?? false
    }

    /// The USR of the type that this def is about.
    /// Even Swift extensions already have this set up.
    /// ObjC categories need transformation.
    public var typeUSR: USR {
        if defKind.isObjCCategory,
            let typeUSR = USR(classFromCategoryUSR: usr) {
            return typeUSR
        }
        return usr
    }

    /// Oops
    public var defChildren: DefItemList {
        children.compactMap { $0 as? DefItem }
    }

    public var description: String {
        "\(name) \(defKind) \(usr) \(location)"
    }

    /// Add a new declnote
    func add(declNote: DeclNote) {
        declNotes.insert(declNote)
    }

    var orderedDeclNotes: [DeclNote] {
        declNotes.sorted(by: <)
    }

    /// After merge, collate the decl notes ready for formatting
    func finalizeDeclNotes() {
        guard !declNotes.isEmpty else {
            return
        }
        declNotesNotice = RichText(orderedDeclNotes
            .map { $0.localized }
            .joined(by: "\n\n"))
    }
}

public typealias DefItemList = Array<DefItem>
