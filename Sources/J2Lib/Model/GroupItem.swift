//
//  GroupItem.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// A list-of-things group page in the docs

public final class GroupItem: Item {
    // abstract

    /// Create a new group based on the type of content, eg. 'All guides'.
    public init(kind: ItemKind, contents: [Item]) {
        super.init(name: kind.name, slug: kind.name, title: kind.title, children: contents)
    }

    /// Sort out the topics of items to get rid of dups or weird gaps.
    /// Probably only needed when the topics come from MARK comments in jazzy mode?
    func rationalizeTopics() {
        guard let firstChild = children.first else {
            return
        }
        // Start an empty topic if there is none
        var currentTopic = firstChild.topic ?? Topic()
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

    /// Visitor
    override func accept(visitor: ItemVisitor, parents: [Item]) {
        visitor.visit(groupItem: self, parents: parents)
    }

    override var kind: ItemKind { .group }

    override var showInToc: ShowInToc { .yes }
}
