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
}

extension Dictionary {
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
