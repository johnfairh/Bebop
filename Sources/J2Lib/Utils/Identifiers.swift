//
//  Identifiers.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// Some quick utilities to help with managing computer-friendly
// identifiers derived from natural-language text
//

extension String {
    /// A simplified version of the string.  May still need %-encoding for URLs etc.
    /// ICU \w is [\p{Ll}\p{Lu}\p{Lt}\p{Lo}\p{Nd}], see how that goes.
    public var slugged: String {
        re_sub(#"[^\w\s]"#, with: "")
            .re_sub(#"\s+"#, with: "-")
            .lowercased()
    }
}

/// A gadget to unique a set of names
public final class StringUniquer {
    private var map = [String : Int]()

    public init() {
    }

    public func unique(_ input: String) -> String {
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
    public mutating func reduceKey(_ key: Key, _ initial: Value, _ reduceValue: (Value) -> Value) -> Value {
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
