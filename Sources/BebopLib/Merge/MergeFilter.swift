//
//  MergeFilter.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
struct MergeFilter: Configurable {
    let minAclOpt = EnumOpt<DefAcl>(l: "min-acl").def(.public)
    let skipUndocumentedOpt = BoolOpt(l: "skip-undocumented")
    let undocumentedTextOpt = LocStringOpt(l: "undocumented-text").def("Undocumented").help("UNDOCTEXT")
    let skipUndocumentedOverrideOpt = BoolOpt(l: "skip-undocumented-override")
    let ignoreInheritedDocsOpt = BoolOpt(l: "ignore-inherited-docs")
    let includeFilesOpt = GlobListOpt(l: "include-source-files").help("FILEPATHGLOB1,FILEPATHGLOB2,...")
    let excludeFilesOpt = GlobListOpt(l: "exclude-source-files").help("FILEPATHGLOB1,FILEPATHGLOB2,...")
    let excludeNamesOpt = StringListOpt(l: "exclude-names").help("NAMEREGEXP1,NAMEREGEXP2,...")

    var minAcl: DefAcl { minAclOpt.value! }
    var undocumentedText: Localized<String> { undocumentedTextOpt.value! }

    let includeAlias: AliasOpt
    let excludeAlias: AliasOpt

    init(config: Config) {
        includeAlias = AliasOpt(realOpt: includeFilesOpt, l: "include")
        excludeAlias = AliasOpt(realOpt: excludeFilesOpt, l: "exclude")
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        try excludeNamesOpt.value.forEach { try $0.re_check() }
        publish.excludedACLs = DefAcl.excludedBy(acl: minAcl).map { $0.rawValue }.joined(separator: ", ")
    }

    /// State carried around while filtering defs
    struct Context {
        /// Have we checked the filename of this def subtree?
        let filenameChecked: Bool
        /// The global list of private protocols, conformances to these not wanted
        let privateProtocols: Set<String>

        /// New context that will re-check the filename
        var recheckFilename: Context {
            Context(filenameChecked: false, privateProtocols: self.privateProtocols)
        }

        /// New context that will stop checking the filename
        var noCheckFilename: Context {
            Context(filenameChecked: true, privateProtocols: self.privateProtocols)
        }

        /// New context
        init(filenameChecked: Bool, privateProtocols: Set<String>) {
            self.filenameChecked = filenameChecked
            self.privateProtocols = privateProtocols
        }

        init(protocols: DefItemList) {
            self.filenameChecked = false
            self.privateProtocols = Set(protocols.flatMap { item in
                [item.name, "\(item.location.moduleName).\(item.name)"]
            })
        }
    }

    /// Filter the forest
    func filter(items: DefItemList) -> DefItemList {
        logDebug("Filter: start, \(items.count) top-level items")

        let privateProtocols = items.filter { $0.defKind.isSwiftProtocol && $0.acl < minAcl }
        logDebug("Filter: found \(privateProtocols.count) private protocols")

        let filtered = items.filter { filter(item: $0, Context(protocols: privateProtocols)) }

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

        guard filterSymbol(name: item.name) else {
            Stats.inc(.filterSymbolName)
            return false
        }

        // :nodoc: excludes from the whole shebang, needs to be done
        // before looking at ACLs and updating those counters.
        guard !item.documentation.isMarkedNoDoc else {
            Stats.inc(.filterNoDoc)
            return false
        }

        guard item.acl >= minAcl || item.hasDefaultExtensionAcl else {
            Stats.inc(.filterMinAclExcluded)
            return false
        }
        Stats.inc(.filterMinAclIncluded)

        item.filterInheritedTypes(exclude: ctx.privateProtocols)

        guard filterDocumentation(item: item) else {
            // counters already done
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
        guard let filename = item.location.filePathname else {
            return true
        }
        for includeGlob in includeFilesOpt.value {
            guard Glob.match(includeGlob, path: filename) else {
                return false
            }
        }
        for excludeGlob in excludeFilesOpt.value {
            if Glob.match(excludeGlob, path: filename) {
                return false
            }
        }
        return true
    }

    /// Def name filtering.
    /// return `true` to keep the item
    func filterSymbol(name: String) -> Bool {
        for pattern in excludeNamesOpt.value {
            if name.re_isMatch(pattern) {
                return false
            }
        }
        return true
    }

    /// Filter based on lack/presence/nature of documentation.
    /// Sort out the default docstring while we're here.
    func filterDocumentation(item: DefItem) -> Bool {
        // Given the option, skip defs without doc-comments
        // that are overriding superclass methods / implementing protocols.
        if skipUndocumentedOverrideOpt.value,
            (item.documentation.source != .docComment &&
             item.documentation.source != .inheritedExplicit),
            let swiftDeclaration = item.swiftDeclaration,
            swiftDeclaration.isOverride {
            Stats.inc(.filterSkipUndocOverride)
            return false
        }

        // Given the option, demote inherited to missing.
        // Don't demote explicitly requested inherited docs via :inherit[full]doc:
        if item.documentation.source == .inherited && ignoreInheritedDocsOpt.value {
            item.documentation = RichDefDocs()
            Stats.inc(.filterIgnoreInheritedDocs)
        }

        // Do we have enough docs? Extensions don't need docs, follow extended type.
        if !item.documentation.isEmpty || item.defKind.isSwiftExtension {
            Stats.inc(.documentedDef)
            return true
        }

        Stats.addUndocumented(item: item)

        if skipUndocumentedOpt.value {
            Stats.inc(.filterSkipUndocumented)
            return false
        }

        item.documentation = .init(undocumented: RichText(undocumentedText))
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
            swiftDeclaration!.inheritedTypes.isEmpty
    }

    /// Remove anything in the 'inherited types' list that doesn't belong
    func filterInheritedTypes(exclude: Set<String>) {
        guard let swiftDecl = swiftDeclaration else {
            return
        }
        swiftDecl.inheritedTypes = swiftDecl.inheritedTypes.filter {
            !exclude.contains($0)
        }
    }
}
