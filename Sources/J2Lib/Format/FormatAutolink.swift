//
//  FormatAutolink.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The result of an autolink lookup.
///
/// (It's a class because we pass it as a ref-counted void * through some C code later on...)
final class Autolink {
    /// A URL suitable for a markdown link to wrap whatever the user typed
    let markdownURL: String
    /// Some html suitable for replacing whatever the user typed
    let html: String

    init(markdownURL: String, html: String) {
        self.markdownURL = markdownURL
        self.html = html
    }
}

final class FormatAutolink: Configurable {
    // Db for language so that we can tell in which language the user wrote their
    // reference to the def.
    struct NameDB {
        let language: DefLanguage
        let db: [String : DefItem]
    }

    private var nameDBs = [NameDB]()

    init(config: Config) {
        config.register(self)
    }

    /// Set up the name database
    func populate(defs: [Item]) {
        let indexer = AutolinkIndexer()
        indexer.walk(items: defs)
        nameDBs.append(NameDB(language: .swift, db: indexer.swiftNameToDef))
        nameDBs.append(NameDB(language: .objc, db: indexer.objCNameToDef))
    }

    // MARK: Lookup

    /// Try to match a def from a name, in a particular naming context.
    func link(for name: String, context: Item) -> Autolink? {
        guard let (def, language) = def(for: name, context: context) else {
            return nil
        }

        guard def !== context else {
            Stats.inc(.autolinkSelfLink)
            return nil
        }

        let markdownURL = context.url.pathToRoot + def.url.url(fileExtension: ".md")
        let primaryURL = context.url.pathToRoot + def.url.url(fileExtension: ".html", language: language)

        guard def.dualLanguage else {
            // simple case
            let html = #"<a href="\#(primaryURL)"><code>\#(name.htmlEscaped)</code></a>"#
            return Autolink(markdownURL: markdownURL, html: html)
        }

        // dual-language def.
        // create html that will show the name of the def in each appropriate language.
        // mark the one the user _didn't_ write as 'secondary' to hide from Dash.
        // if the user wrote the shortest name for the def then use the shortest name in
        // the other language - otherwise use the fully qualified name.
        let primHTML = #"<a href="\#(primaryURL)" class="\#(language.cssName)"><code>\#(name.htmlEscaped)</code></a>"#
        let secLanguage = language.otherLanguage
        let secURL = context.url.pathToRoot + def.url.url(fileExtension: ".html", language: secLanguage)
        let secName: String
        if name == def.name(for: language) {
            secName = def.name(for: secLanguage)
        } else {
            secName = def.fullyQualifiedName(for: secLanguage)
        }
        let secHTML = #"<a href="\#(secURL)" class="\#(secLanguage.cssName) j2-secondary"><code>\#(secName.htmlEscaped)</code></a>"#

        return Autolink(markdownURL: markdownURL, html: primHTML + secHTML)
    }

    /// Search for a def that matches the name in its context.
    /// Return a tuple of the def, if any, and the language in which the user named the def.
    func def(for name: String, context: Item) -> (DefItem, DefLanguage)? {
        // Relative matches for text in the def hierarchy
        if let defContext = context as? DefItem {
            // First try in local scope
            for db in nameDBs {
                let localName = name.inHierarchy(parents: defContext.parentsFromRoot, for: db.language)
                if let localDef = db.db[localName] {
                    Stats.inc(.autolinkLocalLocalScope)
                    return (localDef, db.language)
                }
                // Special case for nested ObjC method references
                if name.isObjCMethodName && defContext.defKind.isObjCStructural && db.language == .objc {
                    let nestedName = "\(defContext.name).\(name)"
                    if let nestedDef = db.db[nestedName] {
                        Stats.inc(.autolinkLocalNestedScope)
                        return (nestedDef, db.language)
                    }
                }
            }
        }

        // Now global (can memoize from hereout)
        let hierarchicalName = name.hierarchical
        for db in nameDBs {
            if let globalDef = db.db[hierarchicalName] {
                Stats.inc(.autolinkLocalGlobalScope)
                return (globalDef, db.language)
            }
        }
        Stats.inc(.autolinkNotAutolinked)
        return nil
    }
}

// MARK: DB builder

private extension Dictionary where Key == String, Value == DefItem {
    mutating func add(_ name: String, _ item: DefItem) {
        if self[name] != nil {
            logDebug("Colliding autolink name \(name)")
        }
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

extension DefItem {
    /// The human-readable fully-qualified name for the def.
    ///
    /// For Swift this does not include the module name.
    ///
    /// For Objective-C this expresses methods like "+[ClassName method:name]".
    func fullyQualifiedName(for language: DefLanguage) -> String {
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
}
