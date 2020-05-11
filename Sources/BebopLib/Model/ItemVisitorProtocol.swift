//
//  ItemVisitorProtocol.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// Implement a algorithm over the `Item` types.
///
/// It turns to often be useful to have the parent path during these times.
/// In the `parents` array, index 0 is a root node (has no parent) and index -1 is the visited item's
/// immediate parent.
public protocol ItemVisitorProtocol {
    func visit(defItem: DefItem, parents: [Item]) throws
    func visit(groupItem: GroupItem, parents: [Item]) throws
    func visit(guideItem: GuideItem, parents: [Item]) throws
    func visit(readmeItem: ReadmeItem, parents: [Item]) throws
}

/// Default implementations do nothing on visit
extension ItemVisitorProtocol {
    /// Do nothing
    public func visit(defItem: DefItem, parents: [Item]) {}
    /// Do nothing
    public func visit(groupItem: GroupItem, parents: [Item]) {}
    /// Do nothing
    public func visit(guideItem: GuideItem, parents: [Item]) {}
    /// Treat the same as guides
    public func visit(readmeItem: ReadmeItem, parents: [Item]) throws {
        try self.visit(guideItem: readmeItem, parents: parents)
    }
}

extension ItemVisitorProtocol {
    /// Visit an item followed by its children.  Depth-first, preorder.
    public func walk(item: Item, parents: [Item] = []) throws {
        try item.accept(visitor: self, parents: parents)
        try walk(items: item.children, parents: parents + [item])
    }

    /// Visit a list of items and their children
    public func walk<S>(items: S, parents: [Item] = []) throws where S: Sequence, S.Element: Item {
        try items.forEach { try walk(item: $0, parents: parents) }
    }

    /// Visit one item only
    public func walkOne(item: Item) throws {
        try item.accept(visitor: self, parents: [])
    }
}
