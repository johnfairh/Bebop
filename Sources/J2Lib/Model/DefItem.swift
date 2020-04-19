//
//  DefItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

import Maaku

/// Base class of definition items -- those that correspond to a definition in
/// some source code.
public class DefItem: Item, CustomStringConvertible {
    /// Location of the definition
    public let location: DefLocation
    /// Kind of the definition
    public let defKind: DefKind
    /// Topic for the item.  This applies to both languages but we figure it out from the primary
    public var defTopic: DefTopic { defKind.defTopic }
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
    public let genericTypeParameters: Set<String>
    /// Extensions on a base type - carried temporarily here and eventually merged
    public internal(set) var extensions: DefItemList
    /// Notes to add to the declaration, added during merge and resolved during format
    public private(set) var declNotes: Set<DeclNote>
    public private(set) var declNotesNotice: RichText?
    /// Any generic constraint on any parent extension
    public internal(set) var extensionConstraint: SwiftGenericReqs?

    /// Create from a gathered definition
    init?(location: DefLocation, gatherDef: GatherDef, uniquer: StringUniquer) {
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
        self.location = DefLocation(baseLocation: location, dict: gatherDef.sourceKittenDict)
        self.defKind = kind
        self.usr = USR(usr)
        self.documentation = RichDefDocs(gatherDef.translatedDocs )

        if kind.isObjC {
            self.objCDeclaration = gatherDef.objCDeclaration
            acl = DefAcl.forObjC
            // police entire Swift personality - name + decl
            if let swiftName = gatherDef.sourceKittenDict.swiftName,
                let swiftDecl = gatherDef.swiftDeclaration {
                otherLanguageName = swiftName
                self.swiftDeclaration = swiftDecl
            } else {
                otherLanguageName = nil
            }
        } else {
            self.swiftDeclaration = gatherDef.swiftDeclaration
            acl = DefAcl(name: name, dict: gatherDef.sourceKittenDict)
            otherLanguageName = nil // todo swift->objc
        }

        let deprecations = [objCDeclaration?.deprecation,
                            swiftDeclaration?.deprecation].compactMap { $0 }
        if !deprecations.isEmpty {
            self.deprecationNotice = RichText(deprecations.joined(by: "\n\n"))
        } else {
            self.deprecationNotice = nil
        }
        self.unavailableNotice = objCDeclaration?.unavailability.flatMap(RichText.init)

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
        self.genericTypeParameters = Set(genericParams.map { $0.name })
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

    public func name(for language: DefLanguage) -> String {
        switch language {
        case .swift: return swiftName ?? name
        case .objc: return objCName ?? name
        }
    }

    /// The human-readable fully-qualified name for the def.
    ///
    /// For Swift this does not include the module name.
    ///
    /// For Objective-C this expresses methods like "+[ClassName method:name]".
    public func fullyQualifiedName(for language: DefLanguage) -> String {
        if language == .objc && name(for: .objc).isObjCMethodName,
            let parent = self.parent as? DefItem {
            var methodName = name(for: .objc)
            let prefix = methodName.removeFirst()
            return "\(prefix)[\(parent.name(for: .objc)) \(methodName)]"
        }
        let items = parentsFromRoot + [self]
        let names = items.compactMap { ($0 as? DefItem)?.name(for: language) }
        return names.joined(separator: ".")
    }

    public var primaryFullyQualifiedName: String {
        fullyQualifiedName(for: primaryLanguage)
    }

    public func namePieces(for language: DefLanguage) -> [DeclarationPiece] {
        switch language {
        case .swift: return swiftDeclaration!.namePieces
        case .objc: return objCDeclaration!.namePieces
        }
    }

    public var primaryNamePieces: [DeclarationPiece] {
        namePieces(for: primaryLanguage)
    }

    public var secondaryNamePieces: [DeclarationPiece]? {
        secondaryLanguage.flatMap { namePieces(for: $0) }
    }

    public override var sortableName: String {
        primaryNamePieces.flattenedName
    }

    public override func title(for language: DefLanguage) -> Localized<String>? {
        switch language {
        case .swift: return swiftName.flatMap { .init(unlocalized: $0) }
        case .objc: return objCName.flatMap { .init(unlocalized: $0) }
        }
    }

    /// A module name for the def - usually where it is written but for an extension, the type's module.
    public var typeModuleName: String {
        if let swiftDecl = swiftDeclaration,
            let typeModuleName = swiftDecl.typeModuleName {
            return typeModuleName
        }
        return location.moduleName
    }

    public override var kind: ItemKind { defKind.metaKind }
    public override var dashKind: String { defKind.dashName }

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
    override func format(formatters: RichText.Formatters) {
        documentation.format(formatters.block)
        deprecationNotice?.format(formatters.block)
        unavailableNotice?.format(formatters.block)
        declNotesNotice?.format(formatters.block)
    }

    /// Format the item's associated declarations
    func formatDeclarations(formatter: RichDeclaration.Formatter) rethrows {
        try swiftDeclaration?.declaration.format(formatter)
        try objCDeclaration?.declaration.format(formatter)
    }

    public var swiftGenericRequirements: SwiftGenericReqs? {
        swiftDeclaration.flatMap { SwiftGenericReqs(declaration: $0.declaration.text) }
    }

    /// Is this a constrained Swift extension?
    public var isSwiftExtensionWithConstraints: Bool {
        defKind.isSwiftExtension && swiftGenericRequirements != nil
    }

    /// Is this a Swift extension that adds protocol conformances?
    public var isSwiftExtensionWithConformances: Bool {
        swiftDeclaration.flatMap {
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

    public var orderedDeclNotes: [DeclNote] {
        declNotes.sorted(by: <)
    }

    /// After merge, collate the decl notes ready for formatting
    func finalizeDeclNotes() {
        var notes = orderedDeclNotes.map { $0.localized }
        if renderAsPage, let constraint = extensionConstraint {
            notes = [constraint.richLong.markdown.mapValues { $0.md }] + notes
        }
        guard !notes.isEmpty else {
            return
        }
        declNotesNotice = RichText(notes.joined(by: "\n\n"))
    }

    /// Is a name bound in the def's generic context?
    public func isGenericTypeParameter(name: String) -> Bool {
        var next: DefItem? = self
        while let item = next {
            guard !item.genericTypeParameters.contains(name) else {
                return true
            }
            next = item.parent as? DefItem
        }
        return false
    }
}

public typealias DefItemList = Array<DefItem>

/// Helper to create the def's location from available info
private extension DefLocation {
    init(baseLocation: DefLocation, dict: SourceKittenDict) {
        let line = dict.docLine
        let startLine = dict.parsedScopeStart
        let endLine = dict.parsedScopeEnd
        let filePathname =
            baseLocation.filePathname == nil ?
                dict.filePath :
                baseLocation.filePathname
        self.init(moduleName: baseLocation.moduleName,
                  passIndex: baseLocation.passIndex,
                  filePathname: filePathname,
                  firstLine: startLine ?? line,
                  lastLine: endLine ?? line)
    }
}
