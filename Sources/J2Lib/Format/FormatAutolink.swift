//
//  FormatAutolink.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The result of an autolink lookup
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
                let localName = name.fullyQualified(context: defContext.parentsFromRoot, for: db.language)
                if let localDef = db.db[localName] {
                    Stats.inc(.autolinkLocalLocalScope)
                    return (localDef, db.language)
                }
                // Special case for nested ObjC method references
                if name.re_isMatch("^[+-]") && defContext.defKind.isObjCStructural && db.language == .objc {
                    let nestedName = "\(defContext.name).\(name)"
                    if let nestedDef = db.db[nestedName] {
                        Stats.inc(.autolinkLocalNestedScope)
                        return (nestedDef, db.language)
                    }
                }
            }
        }

        // Now global (can memoize from hereout)
        let canonicalName = canonicalize(name: name)
        for db in nameDBs {
            if let globalDef = db.db[canonicalName] {
                Stats.inc(.autolinkLocalGlobalScope)
                return (globalDef, db.language)
            }
        }
        Stats.inc(.autolinkNotAutolinked)
        return nil
    }

    func canonicalize(name: String) -> String {
        guard name.re_isMatch(#"^[+-]\["#) else {
            return name
        }

        guard let matches = name.re_match(#"([+-])\[(\w+)(?: ?\(\w+\))? ([\w:]+)\]"#) else {
            return name
        }
        // 1=access 2=classname [category is dropped] 3=method
        return "\(matches[2]).\(matches[1])\(matches[3])"
    }
}

extension Dictionary where Key == String, Value == DefItem {
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
        let fullName = name.fullyQualified(context: parents, for: .swift)
        swiftNameToDef.add(fullName, item)
        swiftNameToDef.add("\(item.location.moduleName).\(fullName)", item)
    }

    /// Calculate names that should look up to the def
    func visit(defItem: DefItem, parents: [Item]) {
        if defItem.defKind.isSwift {
            addWithModule(item: defItem, parents: parents, name: defItem.name)

            // Allow func/etc args elision with `funcName(...)`
            if defItem.name.contains("(") {
                let shortName = defItem.name.re_sub(#"\(.*\)"#, with: "(...)")
                addWithModule(item: defItem, parents: parents, name: shortName)
            }
        } else {
            objCNameToDef.add(defItem.name.fullyQualified(context: parents, for: .objc), defItem)
        }

        // look up in other language (if different)
    }
}

extension String {
    func fullyQualified(context: [Item], for language: DefLanguage) -> String {
        let parentNamePieces = context.compactMap { ($0 as? DefItem)?.name(for: language) }
        return (parentNamePieces + [self]).joined(separator: ".")
    }
}

extension DefItem {
    func fullyQualifiedName(for language: DefLanguage) -> String {
        if language == .objc && name(for: .objc).re_isMatch("^[+-]") {
            var methodName = name(for: .objc)
            let prefix = methodName.removeFirst()
            guard let parent = self.parent as? DefItem else {
                return name(for: .objc)
            }
            return "\(prefix)[\(parent.name(for: .objc)) \(methodName)]"
        }
        let items = parentsFromRoot + [self]
        let names = items.compactMap { ($0 as? DefItem)?.name(for: language) }
        return names.joined(separator: ".")
    }
}
