//
//  MergeDefinitions.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// MergeDefinitions
// - elimination of total duplicate types and availability merging
// - association of extensions/categories with types
// - merging of extensions/categories into types

// MARK: UsrGroups helper

/// An index of lists of items that share a USR.
///
/// USR sharing (and requisite merging) happens because:
/// 1) Multipass gives us multiple copies of the same definiition.
/// 2) There is a Swift extension of a Swift or Objective-C type in our sources.
/// 3) There is an ObjC category of an Objective-C type in our sources.
/// 4) There are multiple Swift extensions or ObjC categories on some type that
///   is not in our sources -- will be a top-level extension in the generated docs.
private final class UsrGroups {
    private var sortOrder: [USR]
    private var groups: [USR: DefItemList]

    /// Create an index from a list of items
    init(items: DefItemList) {
        sortOrder = []
        groups = [:]
        items.forEach { item in
            let newList = groups.reduceKey(item.typeUSR, [item], {$0 + [item]})
            if newList.count == 1 {
                sortOrder.append(item.typeUSR)
            }
        }
    }

    /// Return _and remove from the index_ the group for a USR
    func remove(usr: USR) -> DefItemList {
        groups.removeValue(forKey: usr) ?? []
    }

    /// Map the remaining groups, passing list-head and list-tail (possibly empty)
    /// This map preserves the original order of the items given to our initializer (oh my goodness...)
    func map<T>(_ call: (DefItem, DefItemList) throws -> T) rethrows -> [T] {
        try sortOrder.compactMap { usr -> T? in
            guard var items = groups[usr] else {
                return nil
            }
            precondition(!items.isEmpty)
            let first = items.removeFirst()
            return try call(first, items)
        }
    }

    /// Iterate the groups in some order
    func forEachGroup(_ call: (DefItemList) throws -> Void) rethrows {
        try groups.values.forEach { try call($0 )}
    }
}

fileprivate extension DefItemList {
    /// Transform a list of items by grouping them by USR.  Preserves order.
    func mergeDuplicates(using: (DefItem, [DefItem]) throws -> Void) rethrows -> [DefItem] {
        try UsrGroups(items: self).map { first, rest in
            try using(first, rest)
            return first
        }
    }
}

// MARK: MergeDefinitions

/// MergeDefinitions deals with merging together multiple copies of the same definition,
/// extensions of definitions with definitions, and multiple copies of said extensions.
///
/// There are two main phases to this separated by the `MergeFilter` process.
/// Phase 1 associates (but does not merge) extensions with their types, and merges multiple
/// copies of things that are not in extensions.
///
/// The filter process then prunes this forest by discarding defs the user does not want
/// to see in the docs.
///
/// Phase 2 merges extensions that passed the filter into their types.
///
/// The phasing is such to make filter possible: grouping extensions with their types is necessary
/// to understand access control, and filtering stuff after extension-merging is really hard because
/// we lose sight of where things came from.
struct MergeDefinitions {
    init(config: Config) {
    }

    /// Phase 1 - merge types and link extensions
    ///
    /// Surprisingly complicated because extensions: always occur at the top level but
    /// may extend a nested type ("extension A.B"), may introduce new nested types
    /// ("extension A { struct B {} }""), and may be extensions of types that are introduced
    /// by other extensions (last two examples together).  And we may have multiple copies
    /// of them due to gather passes.
    ///
    func mergePhase1(items: DefItemList) -> DefItemList {
        // Separate extensions
        let (exts, defs) = items.splitPartition { $0.defKind.isExtension }
        let extensionGroups = UsrGroups(items: exts)

        // Merge non-extensions
        let mergedDefs = defs.mergeDuplicates {
            $0.mergePhase1(others: $1)
        }

        // Associate extensions with the types they are extending.
        // First, extensions of types introduced by other extensions
        extensionGroups.forEachGroup { group in
            group.forEach {
                $0.linkExtensions(extensionGroups: extensionGroups)
            }
        }
        // Then extensions of straight types.
        mergedDefs.forEach {
            $0.linkExtensions(extensionGroups: extensionGroups)
        }

        // Clean up any unclaimed extensions
        let unlinkedExts = extensionGroups.map { first, rest -> DefItem in
            first.setExtensions(extensions: rest)
            return first
        }

        return mergedDefs + unlinkedExts
    }

    /// Phase 2 - merge  extensions
    ///
    /// This 'just' needs to walk the forest and eliminate the 'extensions' lists dangling
    /// off some types.
    func mergePhase2(items: DefItemList) -> DefItemList {
        items.forEach { $0.mergePhase2(others: []) }
        return items
    }
}

// MARK: DefItem methods

fileprivate extension DefItem {
    /// Phase 1 merge, part 1: reduce duplicate type definitions.
    ///
    /// The `newItems` all have the same USR as we do.
    /// They will not be independently included in docs.
    /// Either roll the meaning of each `newItem` element into this one or report a warning to record its loss.
    func mergePhase1(others newItems: DefItemList) {
        mergeAvailabilities(with: newItems)
        newItems.forEach { precondition($0.extensions.isEmpty) }

        let allChildren = defChildren + newItems.flatMap { $0.defChildren }
        children = allChildren.mergeDuplicates {
            $0.mergePhase1(others: $1)
        }
    }

    /// Merge the availabilities of a bunch of duplicate definitions into ours
    func mergeAvailabilities(with newItems: DefItemList) {
        newItems.forEach { newItem in
            if defKind == newItem.defKind {
                // A straight duplicate, probably from a different pass.
                mergeAvailabilities(from: newItem)
                Stats.inc(.mergeDupUsr)
            } else {
                logWarning(.localized(.wrnUsrCollision, self, newItem))
                Stats.inc(.mergeDupUsrMismatch)
            }
        }
    }

    /// Add any new availabilities into our set
    func mergeAvailabilities(from newItem: DefItem) {
        if let currentSwiftDecl = swiftDeclaration,
            let newAvailabilities = newItem.swiftDeclaration?.availability {
            newAvailabilities.forEach { availability in
                if !currentSwiftDecl.availability.contains(availability) {
                    currentSwiftDecl.availability.append(availability)
                }
            }
        }
    }

    /// Phase 1 merge, part 2: pick up extensions from the index.
    /// (Could merge with phase1part1 I'm sure, but my head almost exploded getting this far.)
    func linkExtensions(extensionGroups: UsrGroups) {
        if !defKind.isExtension {
            setExtensions(extensions: extensionGroups.remove(usr: usr))
        }
        defChildren.forEach { $0.linkExtensions(extensionGroups: extensionGroups) }
    }

    /// Associate extensions with a primary type.
    /// Corner-case for documentation: if we have a primary type with no docs, but docs on
    /// the extension, move the docs over to the main type.
    /// This is specifically for Xcode Core Data code generation, where the main class is generated
    /// by code without doc comments and users write extensions with docs in their code.
    func setExtensions(extensions: DefItemList) {
        self.extensions = extensions
        if documentation.isEmpty {
            for ext in extensions {
                if !ext.documentation.isEmpty {
                    documentation = ext.documentation
                    break
                }
            }
        }
    }

    /// Phase 2 merge: merge extensions
    ///
    /// Because we can have multiple copies of extensions, some deduplication is necessary
    /// here as well as straight extension merging.
    ///
    /// For example 2x "extension A { struct B {} }" and 1x "extension A.B {}".
    /// When this routine executes for `A.B`, we will have the A.B extension waiting in
    /// 'extensions', having located it during phase 1, and will also have newItems.count = 1
    /// as it holds the second copy of the struct A.B declaration.
    /// All this needs merging together because the struct declarations could have different
    /// content.
    func mergePhase2(others newItems: DefItemList) {
        mergeAvailabilities(with: newItems)

        var exts = extensions
        extensions = []

        if !exts.isEmpty {
            // Mark imported extensions
            markImportedExtensions(extensions: exts)

            // Deal with protocol extensions
            if defKind.isSwiftProtocol {
                exts = mergeProtocolExtensions(extensions: exts)
            }

            // Add topics to extension members
            if defKind.isExtension {
                cascadeTopic()
            }
            exts.forEach { $0.cascadeTopic() }

            // Merge in declarations
            mergeDeclarations(extensions: exts)

            // Constrained extensions at the end
            _ = exts.partition { $0.swiftGenericRequirements != nil }
        }

        let allChildren = defChildren +
            newItems.flatMap { $0.defChildren } +
            exts.flatMap { $0.defChildren }

        children = allChildren.mergeDuplicates {
            $0.mergePhase2(others: $1)
        }
    }
}

// MARK: Import Marker

fileprivate extension DefItem {
    /// Tag extension members that come from a different module to the base type
    func markImportedExtensions(extensions: DefItemList) {
        struct MarkVisitor: ItemVisitorProtocol {
            func visit(defItem: DefItem, parents: [Item]) {
                defItem.add(declNote: .imported(defItem.location.moduleName))
            }
        }
        extensions.forEach { ext in
            if ext.location.moduleName != location.moduleName {
                MarkVisitor().walk(item: ext)
            }
        }
    }
}

// MARK: Protocol Extensions

fileprivate extension DefItem {
    /// Extensions of protocols are unusual:
    /// 1) Spot default implementations and merge into the actual protocol.
    /// 1a) Unless the extension has generic constraints.
    /// 2) Stuff that is not a default implementation needs a flag to identify it as not an extension point.
    func mergeProtocolExtensions(extensions: DefItemList) -> DefItemList {
        extensions.compactMap { ext in
            ext.children = ext.defChildren.filter { extChild in
                guard let protoChild = defChildren.first(where: { child in
                    child.name == extChild.name && child.defKind == extChild.defKind
                }) else {
                    // Extension-only member
                    extChild.add(declNote: .protocolExtensionMember)
                    return true
                }

                // Default impl, but under 'generic' constraints - mark, don't merge
                if ext.isSwiftExtensionWithConstraints {
                    extChild.makeDefaultImplementation()
                    protoChild.add(declNote: .conditionalDefaultImplementationExists)
                    return true
                }

                // Default impl, no constraints - merge.
                protoChild.setDefaultImplementation(from: extChild)
                return false
            }

            return ext.children.isEmpty ? nil : ext
        }
    }

    /// During merge, update docs to indicate a default implementation.
    /// This is when a protocol extension default implementation gets merged into the protocol.
    func setDefaultImplementation(from otherItem: DefItem) {
        documentation.setDefaultImplementation(from: otherItem.documentation)
        if location.moduleName != otherItem.location.moduleName {
            add(declNote: .importedDefaultImplementation(otherItem.location.moduleName))
        } else {
            add(declNote: .defaultImplementation)
        }
        Stats.inc(.mergeDefaultImplementation)

        // hmm availability...
    }

    /// During merge, demote our implementation documentation to defaults of something else.
    /// This is when a protocol extension default implementation stays unmerged with the protocol.
    func makeDefaultImplementation() {
        documentation.makeDefaultImplementation()
        add(declNote: .conditionalDefaultImplementation)
        Stats.inc(.mergeDemoteDefaultImplementation)
    }
}

// MARK: Topic Cascade

fileprivate extension DefItem {
    /// Assign a topic to the extension's children for the extended type's page.
    ///
    /// Categories - use the category name
    /// Swift exts with generic requirements - use them
    /// Other Swift exts - any topic that we have
    ///
    /// This info is mostly discarded by Group unless source-order topic style is enabled.
    func cascadeTopic() {
        precondition(defKind.isExtension)
        guard let firstChild = children.first else {
            return
        }
        if defKind.isObjCCategory,
            firstChild.topic == nil,
            let categoryName = ObjCCategoryName(name) {
            firstChild.topic = Topic(categoryName: categoryName)
        }
        else if let genericReqs = swiftGenericRequirements {
            let genericTopic = Topic(requirements: genericReqs)
            if let existingTopic = firstChild.topic {
                existingTopic.makeGenericRequirement(requirements: genericReqs)
            } else {
                firstChild.topic = genericTopic
            }
            defChildren.forEach { $0.extensionConstraint = genericReqs }
        }
        else if topic != nil && firstChild.topic == nil {
            firstChild.topic = topic
        }
    }
}

// MARK: Declaration merge
fileprivate extension DefItem {
    /// Merge the actual declaration.
    ///
    /// This is Swift-only and the idea is to add extension decls that are inherently interesting,
    /// that is ones that add protocol conformances or, in the case where the head def is itself
    /// an extension, ones that have additional constraints.
    func mergeDeclarations(extensions: DefItemList) {
        guard let baseSwiftDecl = swiftDeclaration?.declaration else {
            return
        }

        let extraDecls = extensions
            .filter { ext in
                ext.isSwiftExtensionWithConformances ||
                    (defKind.isSwiftExtension && ext.isSwiftExtensionWithConstraints)
            }
            .compactMap { $0.swiftDeclaration?.declaration }
            .filter { $0 != baseSwiftDecl }
            .sorted(by: <)
            .uniqued()

        guard !extraDecls.isEmpty else {
            return
        }

        let compoundDecl = ([baseSwiftDecl] + extraDecls)
            .map { $0.text }
            .joined(separator: "\n\n")
        // hmm availability again...

        swiftDeclaration?.declaration = RichDeclaration(compoundDecl)
    }
}
