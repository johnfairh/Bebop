//
//  FormatAbstracts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// Custom abstracts
//
// The file-naming and mapping scheme could do with more thought to use this extensively
// with members etc.  Not really sure what the use case is to be honest.

// MARK: Interface

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

// MARK: Visitor

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

// MARK: GroupItem

extension GroupItem {
    func setCustomAbstract(markdown: Localized<Markdown>, overwrite: Bool) {
        let newMarkdown: Localized<Markdown>
        if !overwrite, let current = customAbstract {
            newMarkdown = current.markdown + "\n\n" + markdown
        } else {
            newMarkdown = markdown
        }
        customAbstract = RichText(newMarkdown)
    }
}

// MARK: DefItem

import Maaku

extension DefItem {
    /// It is messier than expected adding a custom abstract to a def, because we have to
    /// split the markdown into an intro 'abstract' paragraph and the rest as 'discussion' -- the
    /// 'abstract' gets included on the parent page in the exploded style.
    func setCustomAbstract(markdown: Localized<Markdown>, overwrite: Bool) {
        let newAbstract: Localized<Markdown>

        if !overwrite,
            documentation.source != .undocumented,
            let currentAbstract = documentation.abstract {
            newAbstract = markdown + "\n\n" + currentAbstract.markdown
        } else {
            newAbstract = markdown
        }

        let newDocs: Localized<Markdown>
        if let discussion = documentation.discussion {
            newDocs = newAbstract + "\n\n" + discussion.markdown
        } else {
            newDocs = newAbstract
        }

        let newStuff = newDocs.mapValues { md -> (Markdown, Markdown) in
            if let doc = CMDocument(markdown: md),
                let firstPara = doc.removeFirstParagraph() {
                return (firstPara.renderMarkdown(), doc.node.renderMarkdown())
            }

            return (md, Markdown(""))
        }
        documentation.abstract = RichText(newStuff.mapValues { $0.0 })
        documentation.discussion = RichText(newStuff.mapValues { $0.1 })
        // (docsource is unchanged...)
    }
}
