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

/// An index of lists of items that share a USR.
///
/// USR sharing (and requisite merging) happens because:
/// 1) Multipass gives us multiple copies of the same definiition.
/// 2) There is a Swift extension of a Swift or Objective-C type in our sources.
/// 3) There is an ObjC category of an Objective-C type in our sources.
/// 4) There are multiple Swift extensions or ObjC categories on some type that
///   is not in our sources -- will be a top-level extension in the generated docs.
final class UsrGroups {
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
}

extension DefItemList {
    /// The top level merge is different to the others because of Swift extensions.
    /// These are different because extensions always occur at the outer scope, but
    /// may refer to a nested scope (extension A.B).
    ///
    /// So we collect up extensions once, then pick them up as we recurse down the
    /// tree of types.
    ///
    /// Any left-over extensions must be of external types, and we can add them back
    /// to the merged list -- but grouped up, so we have just one representative extension
    /// of a given type.
    func mergeDefinitions() -> DefItemList {
        let (exts, defs) = splitPartition { $0.defKind.isExtension }
        let extensionGroups = UsrGroups(items: exts)

        let mergedDefs = defs.merge(extensions: extensionGroups)

        let unmergedExts = extensionGroups.map { first, rest -> DefItem in
            first.add(extensions: rest)
            return first
        }

        return mergedDefs + unmergedExts
    }

    /// The recursive-step merge.
    ///
    /// Take all the defs and sort into groups, then merge each
    /// group along with the top-level extensions group.
    func merge(extensions: UsrGroups) -> [DefItem] {
        UsrGroups(items: self).map { first, rest in
            first.merge(with: rest, extensions: extensions)
            return first
        }
    }
}

extension DefItem {
    /// Merge a set of items into this one.
    ///
    /// The `newItems` all have the same USR as we do.
    /// They will not be independently included in docs.
    /// Either roll the meaning of each `newItem` element into this one or report a warning to record its loss.
    /// Pick up extensions from `extensions` and record for later.
    func merge(with newItems: DefItemList, extensions: UsrGroups) {
        // Main declaration
        newItems.forEach { newItem in
            if defKind == newItem.defKind {
                // A straight duplicate, probably from a different pass.
                mergeAvailabilities(from: newItem)
            } else {
                logWarning(.localized(.wrnUsrCollision, self, newItem))
            }
        }
        // Remember extensions for later
        add(extensions: extensions.remove(usr: usr))

        // Children - recurse!
        let allChildren = defChildren + newItems.flatMap { $0.defChildren }
        children = allChildren.merge(extensions: extensions)
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
}
