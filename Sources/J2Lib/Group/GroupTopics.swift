//
//  GroupTopics.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import SortedArray

/// How to arrange child items on each page
enum TopicStyle: String, CaseIterable {
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
    let customizer: (DefItem) -> [Item]

    func visit(defItem: DefItem, parents: [Item]) {
        let customizedChildren = customizer(defItem)
        switch style {
        case .logical:
            defItem.makeLogicalTopics(customized: customizedChildren)
        case .source_order, .source_order_defs:
            defItem.makeSourceOrderTopics(customized: customizedChildren)
        }
    }

    func visit(groupItem: GroupItem, parents: [Item]) {
        // Don't reorder or topicize custom groups
        guard !groupItem.groupKind.isCustom else {
            return
        }
        switch style {
        case .logical, .source_order_defs:
            if groupItem.groupKind.isPath {
                groupItem.makePathTopics()
            } else {
                groupItem.makeLogicalTopics()
            }
        case .source_order:
            groupItem.makeSourceOrderTopics()
        }
    }
}

// MARK: Source-Order Style Topics

private extension Item {
    func makeSourceOrderTopics(customized: [Item] = []) {
        var currentTopic: Topic
        if let topic = children.first?.topic {
            currentTopic = topic
        } else {
            currentTopic = Topic(title: customized.isEmpty ? "" : "Other Definitions")
        }

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
        children = customized + children
    }
}

// MARK: Logical-Style Topics

private extension GroupItem {
    /// Just sort them and erase any leftover topic - in logical mode we know they're all the same kind
    func makeLogicalTopics() {
        let topic = Topic()
        children.forEach { $0.topic = topic }
        children.sort { $0.sortableName < $1.sortableName }
    }
}

private extension DefItem {
    /// Group definition members by topic in topic order, then alphabetically (except enum elements!)
    func makeLogicalTopics(customized: [Item]) {
        // Split children into normal and conditional extensions
        let normalChildren = defChildren.prefix { !$0.isStartOfConditionalExtension }
        let extChildren = defChildren.suffix(from: normalChildren.count)

        // Rearrange defs in topic order and give everything the topic, sorting
        // alphabetically within the topic
        let topicChildren = normalChildren.sortedByDefTopic

        // Combine topicized normal children with extensions
        children = customized + topicChildren + extChildren.asLogicalConditionalExtensions
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

private extension Sequence where Element == DefItem {
    /// Rearrange the defitems first into DefTopic order, then sorted alphabetically
    /// within each topic.  Also assign the actual Topic markers.
    var sortedByDefTopic: [Item] {
        var topicsToItems = [DefTopic : [DefItem]]()
        forEach { item in
            topicsToItems.reduceKey(item.defTopic, [item], {$0 + [item]})
        }

        var newItems = [Item]()
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
            newItems += items
        }
        return newItems
    }

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
                currentTopic.useAsGenericRequirement()
            } else {
                child.topic = currentTopic
            }
            sortedChildren.insert((currentTopic.genericRequirements, child))
        }

        return sortedChildren.map { $0.1 }
    }
}

// MARK: Path-Style Topics

private extension GroupItem {
    /// In group-style=path mode we have a random assortment of declarations from the same path
    /// as well as potentially some subgroups for other paths.  Put the subgroups first, without a topic
    /// heading, followed by the declarations in sorted order.
    func makePathTopics() {
        let topic = Topic()
        let (defChildren, groupChildren) = children.splitPartition { $0 is DefItem }
        groupChildren.forEach { $0.topic = topic }
        children = groupChildren.sorted { $0.sortableName < $1.sortableName } +
            (defChildren as! [DefItem]).sortedByDefTopic
    }
}
