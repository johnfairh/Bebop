//
//  FormatAutolink.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

final class FormatAutolink: Configurable {
    private var defsByName = [String : DefItem]()

    init(config: Config) {
        config.register(self)
    }

    /// Set up the name database
    func populate(defs: [Item]) {
        let indexer = AutolinkIndexer()
        indexer.walk(items: defs)
        defsByName = indexer.defsByName
    }

    /// Try to match a def from a name, in a particular naming context.
    func def(for name: String, context: [Item]) -> DefItem? {
        // First try in local scope
        let localName = name.fullyQualified(context: context)
        if let localDef = defsByName[localName] {
            Stats.inc(.autolinkLocalLocalScope)
            return localDef
        }
        // Now global (can memoize from hereout)
        let canonicalName = canonicalize(name: name)
        if let globalDef = defsByName[canonicalName] {
            Stats.inc(.autolinkLocalGlobalScope)
            return globalDef
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

private final class AutolinkIndexer: ItemVisitorProtocol {
    var defsByName = [String : DefItem]()

    private func add(_ name: String, _ item: DefItem) {
        if defsByName[name] != nil {
            logDebug("Colliding autolink name \(name)")
        }
        defsByName[name] = item
    }

    /// For a def with name 'A.B' cache it as both 'A.B' and '_modulename_.A.B'
    private func addWithModule(item: DefItem, parents: [Item], name: String) {
        let fullName = name.fullyQualified(context: parents)
        add(fullName, item)
        add("\(item.location.moduleName).\(fullName)", item)
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
            add(defItem.name.fullyQualified(context: parents), defItem)
        }

        // look up in other language (if different)
    }
}

extension String {
    func fullyQualified(context: [Item]) -> String {
        let parentNamePieces = context.filter { $0.kind.isCode }.map { $0.name }
        return (parentNamePieces + [self]).joined(separator: ".")
    }
}
