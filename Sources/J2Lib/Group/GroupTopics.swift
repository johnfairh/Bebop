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
            fallthrough
        case .source_order, .source_order_defs:
            cleanUpSourceOrderTopics(items: defItem.children)
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        switch style {
        case .logical, .source_order_defs:
            // Erase any source-mark topics and alphabetize
            let topic = Topic()
            groupItem.children.forEach { $0.topic = topic }
            groupItem.children.sort { $0.name < $1.name }
        case .source_order:
            cleanUpSourceOrderTopics(items: groupItem.children)
        }
    }

    /// Massage existing topics created from MARK comments or pragmas, jazzy-style,
    /// so that every item has a topic and consecutive topics are merged.
    func cleanUpSourceOrderTopics(items: [Item]) {
        var currentTopic = items.first?.topic ?? Topic()
        items.forEach { item in
            guard let itemTopic = item.topic else {
                // add to current topic
                item.topic = currentTopic
                return
            }
            if itemTopic === currentTopic {
                // already there
                return
            }
            if itemTopic == currentTopic {
                // textual dup (different file origin/sorting artefact?), merge
                item.topic = currentTopic
                return
            }
            // New topic!
            currentTopic = itemTopic
        }
    }
}

// MARK: DefItem

/// Helper to figure out the real topic from info, where our Gathered info is incomplete
/// - objc .property might be a class property
/// - objc .method might be initializer
/// - swift .subscript might be class/static subscript
/// - swift method might be init
/// - swift method might be deinit
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
                if decl.namePieces.contains(.other("static")) {
                    return .staticSubscript
                } else if decl.namePieces.contains(.other("class")) {
                    return .classSubscript
                }
            }
            return topic
        case .method:
            if name == "deinit" {
                return .deinitializer
            } else if name.re_isMatch(#"^init[?!]\("#) {
                return .initializer
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
