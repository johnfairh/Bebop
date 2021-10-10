//
//  FormatAutolink.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// The result of an autolink lookup.
///
/// (It's a class because we pass it as a ref-counted void * through some C code later on...)
final class Autolink {
    /// A URL suitable for a markdown link to wrap whatever the user typed
    let markdownURL: String
    /// A URL (href) for simple use in declarations
    let primaryURL: String
    /// Some html suitable for replacing whatever the user typed
    let html: String

    init(markdownURL: String, primaryURL: String, html: String) {
        self.markdownURL = markdownURL
        self.primaryURL = primaryURL
        self.html = html
    }

    convenience init(url: String, html: String) {
        self.init(markdownURL: url, primaryURL: url, html: html)
    }

    convenience init(url: URL, text: String) {
        let href = url.absoluteString
        self.init(markdownURL: href, primaryURL: href, html: #"<a href="\#(href)">\#(text.htmlEscaped)</a>"#)
    }
}

final class FormatAutolink: Configurable {
    let autolinkApple: FormatAutolinkApple
    let autolinkRemote: FormatAutolinkRemote

    static let commonUnlinked = Set(["true", "false", "nil", "NULL", "null"])

    // ok i'm too dumb to write this as one hash...
    private(set) var cacheHits = [String:Autolink]()
    private(set) var cacheMisses = FormatAutolink.commonUnlinked

    // Db for language so that we can tell in which language the user wrote their
    // reference to the def.
    struct NameDB {
        let language: DefLanguage
        let db: [String : DefItem]
    }

    private var nameDBs = [NameDB]()

    init(config: Config) {
        autolinkApple = FormatAutolinkApple(config: config)
        autolinkRemote = FormatAutolinkRemote(config: config)
        config.register(self)
    }

    /// Set up the name database
    func populate(defs: [Item]) {
        let indexer = AutolinkIndexer()
        try! indexer.walk(items: defs)
        nameDBs.append(NameDB(language: .swift, db: indexer.swiftNameToDef))
        nameDBs.append(NameDB(language: .objc, db: indexer.objCNameToDef))
    }

    // MARK: Lookup

    /// HTML autolink fixup.
    ///
    /// When we generate autolinks we include a placeholder meaning 'from the current page to the doc root'.
    /// Then after the entire HTML page is rendered we substitute back.
    ///
    /// This is how jazzy did it, and I thought, "ugh how gross".  The thing is, it turns out to be really hard to know
    /// at the point we are generating the hrefs where the html will eventually end up in the doc hierarchy: because
    /// of custom groups, because of nesting, because of separate-children ... I tried a bunch of ways and they all
    /// suck / fail.  So, revert to what works.
    ///
    /// In fact it's uglier than jazzy, who manages to do it after mustache has generated the entire page.
    /// Because we have the intermediate json formats in GenPages/SIte we have to sub as the structured
    /// page data is being built.  Yuck.
    static let AUTOLINK_TOKEN = UUID().uuidString

    static func fixUpAutolinks(text: String, pathToRoot: String) -> String {
        text.re_sub(AUTOLINK_TOKEN, with: pathToRoot)
    }

    /// Try to match a def from a name, in a particular naming and link context.
    ///
    /// These are different in practice only for topics, which are evaluated inside the namespace of
    /// their type, but rendered on the same page as the type.
    func link(for name: String, context: Item, contextLanguage: DefLanguage? = nil) -> Autolink? {
        if let defItem = context as? DefItem,
            defItem.isGenericTypeParameter(name: name) {
            return nil
        }

        guard !name.starts(with: "."),              // implicit scope, impossible to resolve
              !name.re_isMatch(#"^\$.*\$$"#) else { // katex math
            return nil
        }

        let unmangledName = name
            .re_sub("^<doc:(.*)>$", with: "$1") // docc markup
            .re_sub("(?<!^)-.+$", with: "")     // docc trailing '-blah' discriminator

        let nameToSearch = unmangledName
            .re_sub("^@(.*)$", with: "$1")            // property wrapper
            .replacingOccurrences(of: "/", with: ".") // docc syntax

        let nameToDisplay = unmangledName
            .re_sub("^.*/", with: "") // docc syntax

        let autolink = { () -> Autolink? in
            // First try a def in this docset, name resolved relative to current context
            if let (def, language) = def(for: nameToSearch, context: context) {
                return linkTo(defItem: def, language: language, from: nameToDisplay, context: context)
            }

            // Cache results from now on because not context-sensitive and somewhat
            // expensive to calculate (module searching).
            if let cachedResult = cacheHits[nameToSearch] {
                Stats.inc(.autolinkCacheHitHit)
                return cachedResult
            }
            if cacheMisses.contains(nameToSearch) {
                Stats.inc(.autolinkCacheHitMiss)
                return nil
            }

            let language = contextLanguage ?? (context as? DefItem)?.primaryLanguage

            // Configured remote docsets before apple.com fallback
            if let link = autolinkRemote.autolink(name: nameToSearch) ??
                autolinkApple.autolink(text: nameToSearch, language: language) {
                cacheHits[nameToSearch] = link
                return link
            }
            cacheMisses.insert(nameToSearch)
            return nil
        }()

        // Record unresolved might-be-links.
        if autolink == nil &&
            nameToSearch != context.name &&
            !Self.commonUnlinked.contains(nameToSearch) {
            Stats.addUnresolved(name: name, context: context.name)
        }
        return autolink
    }

    /// Create the Autolink for a link to one of our defs
    private func linkTo(defItem def: DefItem, language: DefLanguage, from name: String, context: Item) -> Autolink? {
        guard def !== context else {
            Stats.inc(.autolinkSelfLink)
            return nil
        }

        let markdownURL = FormatAutolink.AUTOLINK_TOKEN + def.url.url(fileExtension: ".md")
        let primaryURL = FormatAutolink.AUTOLINK_TOKEN + def.url.url(fileExtension: ".html", language: language)

        guard def.dualLanguage else {
            // simple case
            let html = #"<a href="\#(primaryURL)"><code>\#(name.htmlEscaped)</code></a>"#
            return Autolink(markdownURL: markdownURL, primaryURL: primaryURL, html: html)
        }

        // dual-language def.
        // create html that will show the name of the def in each appropriate language.
        // mark the one the user _didn't_ write as 'secondary' to hide from Dash.
        // if the user wrote the shortest name for the def then use the shortest name in
        // the other language - otherwise use the fully qualified name.
        let primHTML = #"<a href="\#(primaryURL)" class="\#(language.cssName)"><code>\#(name.htmlEscaped)</code></a>"#
        let secLanguage = language.otherLanguage
        let secURL = FormatAutolink.AUTOLINK_TOKEN + def.url.url(fileExtension: ".html", language: secLanguage)
        let secName: String
        if name == def.name(for: language) {
            secName = def.name(for: secLanguage)
        } else {
            secName = def.fullyQualifiedName(for: secLanguage)
        }
        let secHTML = #"<a href="\#(secURL)" class="\#(secLanguage.cssName) j2-secondary"><code>\#(secName.htmlEscaped)</code></a>"#

        return Autolink(markdownURL: markdownURL, primaryURL: primaryURL, html: primHTML + secHTML)
    }

    /// Search for a def that matches the name in its context.
    /// Return a tuple of the def, if any, and the language in which the user named the def.
    func def(for name: String, context: Item) -> (DefItem, DefLanguage)? {
        // First look for a ref to a nested name that assumes part of this item's
        // prefix.  Eg. "B" -> "A.B" from context "A.C".
        if let defContext = context as? DefItem {
            for db in nameDBs {
                var contextDefParents = defContext.parentsFromRoot.compactMap { $0 as? DefItem }

                while !contextDefParents.isEmpty {
                    let localName = name.inHierarchy(parents: contextDefParents, for: db.language)
                    if let localDef = db.db[localName] {
                        Stats.inc(.autolinkLocalLocalScope)
                        return (localDef, db.language)
                    }

                    let _ = contextDefParents.popLast()
                }
            }
        }

        // Second look for a global name.  This is split out from the first part
        // because of ObjC and its non-obvious method names.
        let hierarchicalName = name.hierarchical
        for db in nameDBs {
            if let globalDef = db.db[hierarchicalName] {
                Stats.inc(.autolinkLocalGlobalScope)
                return (globalDef, db.language)
            }
        }

        // Finally look for a nested name.  Not what Swift typing rules allow, so
        // must be last: this is an affordance for people who write refs to methods
        // in docs for a class etc.
        if let defContext = context as? DefItem {
            for db in nameDBs {
                if let nestedDef = db.db["\(defContext.name).\(name)"] {
                    Stats.inc(.autolinkLocalNestedScope)
                    return (nestedDef, db.language)
                }
            }
        }

        Stats.inc(.autolinkNotAutolinked)
        return nil
    }
}

// MARK: DB builder

private extension Dictionary where Key == String, Value == DefItem {
    mutating func add(_ name: String, _ item: DefItem) {
        self[name] = item
    }
}

private final class AutolinkIndexer: ItemVisitorProtocol {
    var swiftNameToDef = [String : DefItem]()
    var objCNameToDef = [String : DefItem]()

    /// For a def with name 'A.B' cache it as both 'A.B' and '_modulename_.A.B'
    private func addWithModule(item: DefItem, parents: [Item], name: String) {
        let fullName = name.inHierarchy(parents: parents, for: .swift)
        swiftNameToDef.add(fullName, item)
        swiftNameToDef.add("\(item.location.moduleName).\(fullName)", item)
    }

    /// Calculate names that should look up to the def
    func visit(defItem: DefItem, parents: [Item]) {
        if let swiftName = defItem.swiftName {
            addWithModule(item: defItem, parents: parents, name: swiftName)

            // Allow func/etc args elision with `funcName(...)`
            if swiftName.contains("(") {
                let shortName = swiftName.re_sub(#"\(.*\)"#, with: "(...)")
                addWithModule(item: defItem, parents: parents, name: shortName)
            }
        }

        if let objCName = defItem.objCName {
            objCNameToDef.add(objCName.inHierarchy(parents: parents, for: .objc), defItem)
        }
    }
}

// MARK: Naming helpers

extension String {
    /// The hierarchical name for this flat name inserted into the given parent chain  in the given language.
    /// Result is suitable only for looking up in dictionaries, not human-friendly format.
    func inHierarchy(parents: [Item], for language: DefLanguage) -> String {
        let parentNamePieces = parents.compactMap { ($0 as? DefItem)?.name(for: language) }
        return (parentNamePieces + [self]).joined(separator: ".")
    }

    /// Get a value suitable for autolink lookup from this possibly-qualified user-friendly name
    ///
    /// This only means something for a "+[Class method:name]" situation that we need to
    /// shuffle around to "Class.+method:name" for lookup.
    var hierarchical: String {
        guard isObjCClassMethodName,
            let matches = re_match(#"([+-])\s*\[(\w+)(?: ?\(\w+\))? ([\w:]+)\]"#) else {
            return self
        }
        // 1=access 2=classname [category is dropped] 3=method
        return "\(matches[2]).\(matches[1])\(matches[3])"
    }

    // These are best-effort "sniff what the user / compiler is doing"

    var isObjCMethodName: Bool {
        re_isMatch(#"^[+-]\s*\w"#)
    }

    var isObjCClassMethodName: Bool {
        re_isMatch(#"^[+-]\s*\["#)
    }
}
