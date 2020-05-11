//
//  Identifiers.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

//
// Some quick utilities to help with managing computer-friendly
// identifiers derived from natural-language text
//

extension String {
    /// A simplified version of the string.  May still need %-encoding for URLs etc.
    /// ICU \w is [\p{Ll}\p{Lu}\p{Lt}\p{Lo}\p{Nd}], see how that goes.
    var slugged: String {
        let str = re_sub(#"[^\w\s\p{So}]"#, with: "")
                     .re_sub(#"\s+"#, with: "-")
                     .lowercased()
        if str.isEmpty && !isEmpty {
            return "e"
        }
        return str
    }
}

/// A gadget to unique a set of names
final class StringUniquer {
    private var map = [String : Int]()

    init() {
    }

    func unique(_ input: String) -> String {
        let dupCount = map.reduceKey(input, 0, { $0 + 1 })
        return dupCount == 0 ? input : input + String(dupCount)
    }

    func reset() {
        map = .init()
    }
}

extension Dictionary {
    /// Reduce a new item into a key.  If key absent, is `initial`, otherwise via `reduceValue`.
    /// Return the new value for the key.
    @discardableResult
    mutating func reduceKey(_ key: Key, _ initial: Value, _ reduceValue: (Value) -> Value) -> Value {
        let newValue: Value
        if let existing = self[key] {
            newValue = reduceValue(existing)
        } else {
            newValue = initial
        }
        self[key] = newValue
        return newValue
    }
}

extension MutableCollection {
    /// Splits the collection into a part that satsifies the predicate and a part that does not.
    ///
    /// Preserves order.
    func splitPartition(by filter: (Element) throws -> Bool) rethrows -> ([Element], [Element]) {
        var include = [Element]()
        var exclude = [Element]()
        try forEach { element in
            // ?: isn't an lvalue ... /sigh
            if try filter(element) { include.append(element) }
            else { exclude.append(element) }
        }
        return (include, exclude)
    }
}

extension Sequence where Element: Equatable {
    /// Return an array collapsing consecutive identical elements down to one.
    ///
    /// Preserves order.  Sort first to eliminate any duplicates.
    func uniqued() -> Array<Element> {
        var result = [Element]()
        var iterator = makeIterator()
        var previous: Element? = nil
        while let next = iterator.next() {
            if next != previous {
                result.append(next)
                previous = next
            }
        }
        return result
    }
}

extension Sequence where Element: Hashable {
    /// Return a duplicated value in the sequence, or `nil` if none.
    var firstDuplicate: Element? {
        var cache = Set<Element>()
        for element in self {
            if cache.contains(element) {
                return element
            }
            cache.insert(element)
        }
        return nil
    }
}
