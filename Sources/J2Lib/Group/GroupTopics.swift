//
//  GroupTopics.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import SortedArray

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
        children.sort { $0.sortableName < $1.sortableName }
    }
}

private extension DefItem {
    /// Group definition members by topic in topic order, then alphabetically (except enum elements!)
    func makeLogicalTopics() {
        // Split children into normal and conditional extensions
        let normalChildren = defChildren.prefix { !$0.isStartOfConditionalExtension }
        let extChildren = defChildren.suffix(from: normalChildren.count)

        // Bucket normal children by topic
        var topicsToItems = [DefTopic : [DefItem]]()
        normalChildren.forEach { child in
            topicsToItems.reduceKey(child.defTopic, [child], {$0 + [child]})
        }

        // Now order in topic order and give everything the topic, sorting
        // alphabetically within the topic
        var newChildren = [Item]()
        DefTopic.allCases.forEach { defTopic in
            guard var items = topicsToItems[defTopic] else {
                return
            }
            let topic = Topic(defTopic: defTopic)
            items.forEach { $0.topic = topic }
            // Frustrating special case: sorting enum elements looks weird :(
            if defTopic != .enumElement {
                items.sort { $0.sortableName < $1.sortableName }
            }
            newChildren += items
        }

        // Combine topicized normal children with extensions
        children = newChildren + extChildren.asLogicalConditionalExtensions
    }

    /// Spot the markers left by group
    var isStartOfConditionalExtension: Bool {
        if let topic = topic,
            topic.kind == .genericRequirements {
            return true
        }
        return false
    }
}

private extension ArraySlice where Element == DefItem {
    /// Clean up topics left over from source-marks.
    /// Arrange the extensions alphabetically sorted by their generic reqs
    /// Sort the extension contents by topic and then by name
    var asLogicalConditionalExtensions: [DefItem] {
        var sortedChildren = SortedArray<(String, DefItem)> { lhs, rhs in
            if lhs.0 != rhs.0 {
                return lhs.0 < rhs.0 // sort by generic requirements
            }
            if lhs.1.defTopic != rhs.1.defTopic {
                return lhs.1.defTopic < rhs.1.defTopic // then by topic
            }
            return lhs.1.sortableName < rhs.1.sortableName // then by name
        }

        var currentTopic: Topic! = nil

        forEach { child in
            if child.isStartOfConditionalExtension {
                currentTopic = child.topic
                currentTopic?.useAsGenericRequirement()
            } else {
                child.topic = currentTopic
            }
            sortedChildren.insert((currentTopic.genericRequirements, child))
        }

        return sortedChildren.map { $0.1 }
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
