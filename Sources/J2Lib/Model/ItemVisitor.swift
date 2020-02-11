//
//  ItemVisitor.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Implement a algorithm over the `Item` types.
///
/// It turns to often be useful to have the parent path during these times.
/// In the `parents` array, index 0 is a root node (has no parent) and index -1 is the visited item's
/// immediate parent.
public protocol ItemVisitor {
    func visit(defItem: DefItem, parents: [Item])
    func visit(groupItem: GroupItem, parents: [Item])
    func visit(guideItem: GuideItem, parents: [Item])
    func visit(readmeItem: ReadmeItem, parents: [Item])
}

/// Default implementations do nothing on visit
extension ItemVisitor {
    /// Do nothing
    public func visit(defItem: DefItem, parents: [Item]) {}
    /// Do nothing
    public func visit(groupItem: GroupItem, parents: [Item]) {}
    /// Do nothing
    public func visit(guideItem: GuideItem, parents: [Item]) {}
    /// Treat the same as guides
    public func visit(readmeItem: ReadmeItem, parents: [Item]) {
        self.visit(guideItem: readmeItem, parents: parents)
    }
}

extension ItemVisitor {
    /// Visit  an item and its children
    func walk(item: Item, parents: [Item] = []) {
        item.accept(visitor: self, parents: parents)
        walk(items: item.children, parents: parents + [item])
    }

    /// Visit a list of items and their children
    func walk<S>(items: S, parents: [Item] = []) where S: Sequence, S.Element: Item {
        items.forEach { walk(item: $0, parents: parents) }
    }
}
