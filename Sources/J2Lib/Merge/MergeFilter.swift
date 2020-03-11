//
//  MergeFilter.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// MergeFilter removes defs from the forest that shouldn't be there.
///
/// Filepath include/excludes
///
/// ACL filtering and consequences thereof, empty extensions
///
/// :nodoc:
///
/// skip-undocumented
///
/// undocumented-text
///
public struct MergeFilter: Configurable {
    let minAclOpt = EnumOpt<DefAcl>(l: "min-acl").def(.public)
    let skipUndocumentedOpt = BoolOpt(l: "skip-undocumented")
    var minAcl: DefAcl { minAclOpt.value! }

    init(config: Config) {
        config.register(self)
    }

    /// State carried around while filtering defs
    struct Context {
        /// Have we checked the filename of this def subtree?
        var filenameChecked: Bool
        /// The global list of private protocols, conformances to these not wanted
        let privateProtocols: DefItemList

        /// New context that will re-check the filename
        var recheckFilename: Context {
            Context(filenameChecked: false, self.privateProtocols)
        }

        /// New context that will stop checking the filename
        var noCheckFilename: Context {
            Context(filenameChecked: true, self.privateProtocols)
        }

        /// New context
        init(filenameChecked: Bool = false, _ privateProtocols: DefItemList) {
            self.filenameChecked = filenameChecked
            self.privateProtocols = privateProtocols
        }
    }

    /// Filter the forest
    func filter(items: DefItemList) -> DefItemList {
        logDebug("Filter: start, \(items.count) top-level items")

        let privateProtocols = items.filter { $0.defKind.isSwiftProtocol && $0.acl < minAcl }
        logDebug("Filter: found \(privateProtocols.count) private protocols")

        let filtered = items.filter { filter(item: $0, Context(privateProtocols)) }

        logDebug("Filter: done, \(filtered.count) top-level items")
        return filtered
    }

    /// Search for reasons to not document the item; return `true` to keep it.
    ///
    /// SIde effects:
    /// - filter out its children and associated extensions.
    /// - strip references to private (inaccessible) protocol conformances.
    /// - set undocumented text
    /// - update stats, counters and db of defs that need documenting
    ///
    /// - parameter checkFilename: Check the def's filename against the include/exclude
    ///   arguments.  This is sort of repetitive so we minimize it slightly.  Can't do it much earlier
    ///   in the process otherwise we'd miss private protocols defined in the excluded files....
    func filter(item: DefItem, _ ctx: Context) -> Bool {
        guard ctx.filenameChecked || filterFilename(item: item) else {
            Stats.inc(.filterFilename)
            return false
        }

        // :nodoc: excludes from the whole shebang, needs to be done
        // before looking at ACLs and updating those counters.
        guard filterNoDoc(item: item) else {
            Stats.inc(.filterNoDoc)
            return false
        }

        guard item.acl >= minAcl || item.hasDefaultExtensionAcl else {
            Stats.inc(.filterMinAclExcluded)
            return false
        }
        Stats.inc(.filterMinAclIncluded)

        filterInheritedTypes(item: item)

        guard filterDocumentation(item: item) else {
            return false
        }

        item.extensions = item.extensions.filter { filter(item: $0, ctx.recheckFilename) }

        item.children = item.defChildren.filter { filter(item: $0, ctx.noCheckFilename) }

        guard !item.isUselessExtension else {
            Stats.inc(.filterUselessExtension)
            return false
        }

        return true
    }

    /// Filename include/exclude filtering.
    /// Return `true` to keep the item.
    func filterFilename(item: DefItem) -> Bool {
        true
    }

    /// NoDoc filtering.
    /// Return `true` to keep the item
    func filterNoDoc(item: DefItem) -> Bool {
        true
    }

    /// Protocol conformance editting - remove refs to things that are known to be 'private'
    /// (in this context means beneath min-acl. )
    func filterInheritedTypes(item: DefItem) {
    }

    /// Filter based on lack/presence/nature of documentation.
    /// Sort out the default docstring while we're here.
    func filterDocumentation(item: DefItem) -> Bool {
        /* if skip-overrides and is-override and docs-from-override {
         *    return false /* drop the def */
         * }
         */

        guard item.documentation.isEmpty && !item.defKind.isSwiftExtension else {
            // Docs or extension -- no docs needed here - original type has
            // no docs, extn docs are often just lost, follow the extended type.
            return true
        }

        Stats.addUndocumented(item: item)

        if skipUndocumentedOpt.value {
            Stats.inc(.filterSkipUndocumented)
            return false
        }

        item.documentation = .init(abstract: RichText("Undocumented."))
        return true
    }
}

// MARK: DefItem helpers

fileprivate extension DefItem {
    /// Swift extensions' ACLs aren't figured out properly on the way in, give them
    /// the benefit of the doubt and fix up later.
    var hasDefaultExtensionAcl: Bool {
        defKind.isSwiftExtension &&
            acl == .internal
    }

    /// If a Swift extension is stripped of all its members and has no leftover
    /// protocol conformances (after excluding private protocols) then it is
    /// useless and gets thrown away.
    var isUselessExtension: Bool {
        defKind.isSwiftExtension &&
            defChildren.isEmpty &&
            (swiftDeclaration?.inheritedTypes ?? []).isEmpty
    }

}
