//
//  GroupTopics.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// How to arrange child items on each page
public enum TopicStyle: String, CaseIterable {
    /// In a group, alphabetical.  In a def, a topic per kind (method, property, etc.) and alphabetical within,
    /// with conditional extensions in their own topic.
    case logical
    /// According to the source code order, using MARK comments/pragmas to create topics.
    /// LIke jazzy does.
    case source_order
    /// Like `sourceOrder` for def pages.  Like `logical` for group pages.
    case source_order_defs
}

/// Visitor to assign topics to a group and its descendents
struct TopicCreationVisitor: ItemVisitorProtocol {
    let style: TopicStyle

    func visit(defItem: DefItem, parents: [Item]) {
        switch style {
        case .logical:
            defItem.makeLogicalTopics()
        case .source_order, .source_order_defs:
            defItem.makeSourceOrderTopics()
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        switch style {
        case .logical, .source_order_defs:
            groupItem.makeLogicalTopics()
        case .source_order:
            groupItem.makeSourceOrderTopics()
        }
    }
}

// MARK: Source-Order Style Topics

private extension Item {
    func makeSourceOrderTopics() {
        var currentTopic = children.first?.topic ?? Topic()
        children.forEach { child in
            guard let childTopic = child.topic else {
                // add to current topic
                child.topic = currentTopic
                return
            }
            if childTopic === currentTopic {
                // already there
                return
            }
            if childTopic == currentTopic {
                // textual dup (different file origin/sorting artefact?), merge
                child.topic = currentTopic
                return
            }
            // New topic!
            currentTopic = childTopic
        }
    }
}

// MARK: Logical-Style Topics

private extension GroupItem {
    /// Just sort them and erase any leftover topic
    func makeLogicalTopics() {
        let topic = Topic()
        children.forEach { $0.topic = topic }
        children.sort { $0.name < $1.name }
    }
}

private extension DefItem {
    /// Group definition members by topic in topic order, then alphabetically (except enum elements!)
    func makeLogicalTopics() {
        var topicsToItems = [DefTopic : [Item]]()
        defChildren.forEach { childItem in
            topicsToItems.reduceKey(childItem.defTopic, [childItem], {$0 + [childItem]})
        }
        var newChildren = [Item]()
        DefTopic.allCases.forEach { defTopic in
            guard var items = topicsToItems[defTopic] else {
                return
            }
            let topic = Topic(defTopic: defTopic)
            items.forEach { $0.topic = topic }
            if defTopic != .enumElement {
                items.sort { $0.name < $1.name }
            }
            newChildren += items
        }
        children = newChildren
    }
}


// MARK: DefItem to be refactored

/// Helper to figure out the real topic from info, where our Gathered info is incomplete
/// - objc .property might be a class property
/// - objc .method might be initializer
/// - swift .subscript might be class/static subscript
private extension DefItem {
    /// Topic for the item.  This applies to both languages but we figure it out from the primary
    var defTopic: DefTopic {
        defKind.isSwift ? improvedSwiftTopic : improvedObjCTopic
    }

    var improvedSwiftTopic: DefTopic {
        let topic = defKind.defTopic
        switch topic {
        case .subscript:
            if let decl = swiftDeclaration {
                if decl.declaration.text.contains(" static ") {
                    return .staticSubscript
                } else if decl.declaration.text.contains(" class ") {
                    return .classSubscript
                }
            }
            return topic
        default:
            return topic
        }
    }

    var improvedObjCTopic: DefTopic {
        let topic = defKind.defTopic
        switch topic {
        case .property:
            if let decl = objCDeclaration {
                if decl.declaration.text.re_isMatch(#"\(.*?class.*?\)"#) {
                    return .classProperty
                }
            }
            return topic
        case .method:
            if name.re_isMatch(#"[+-]\s*init"#) {
                return .initializer
            }
            return topic
        default:
            return topic
        }
    }
}
