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
