//
//  FormatAbstracts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// Custom abstracts

final class FormatAbstracts: Configurable {
    let customAbstractsOpt = GlobListOpt(l: "custom-abstracts").help("FILEPATHGLOB1,FILEPATHGLOB2,...")
    let customAbstractOverwriteOpt = BoolOpt(l: "custom-abstract-overwrite")

    let abstractAliasOpt: AliasOpt

    init(config: Config) {
        abstractAliasOpt = AliasOpt(realOpt: customAbstractsOpt, l: "abstract")
        config.register(self)
    }

    func attach(items: [Item]) throws {
        let abstracts = try customAbstractsOpt.value.readLocalizedMarkdownFiles()
        let visitor = AbstractVisitor(abstracts: abstracts, overwrite: customAbstractOverwriteOpt.value)
        visitor.walk(items: items)
        if !visitor.abstracts.isEmpty {
            let unmatched = visitor.abstracts.keys
            logWarning(.localized(.wrnUnmatchedAbstracts, unmatched.count, unmatched.joined(separator: ",")))
        }
    }
}

private final class AbstractVisitor: ItemVisitorProtocol {
    var abstracts: [String: Localized<Markdown>]
    let overwrite: Bool

    init(abstracts: [String: Localized<Markdown>], overwrite: Bool ) {
        self.abstracts = abstracts
        self.overwrite = overwrite
    }

    func visit(defItem: DefItem, parents: [Item]) {
        if let md = abstracts.removeValue(forKey: defItem.name) {
            defItem.setCustomAbstract(markdown: md, overwrite: overwrite)
            Stats.inc(.customAbstractDef)
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        if let md = abstracts.removeValue(forKey: groupItem.name) {
            groupItem.setCustomAbstract(markdown: md, overwrite: overwrite)
            Stats.inc(.customAbstractGroup)
        }
    }

    func visit(guideItem: GuideItem, parents: [Item]) {
        if abstracts[guideItem.name] != nil {
            logWarning(.localized(.wrnGuideAbstract, guideItem.name))
        }
    }
}
