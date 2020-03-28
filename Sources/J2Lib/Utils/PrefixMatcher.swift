//
//  PrefixMatcher.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// A data structure to support identifying one of a set of strings from its unique prefix.
struct PrefixMatcher {
    // This is probably a trie
    private enum Tree {
        case stub
        case leaf(String)
        case node(Dictionary<Character, Tree>)

        mutating func insert(_ newStr: String) {
            precondition(!newStr.isEmpty)
            switch self {
            case .stub:
                // Unique - remember
                self = .leaf(newStr)

            case .leaf(let curStr):
                guard newStr != curStr else {
                    // double insert of same thing - fine
                    break
                }
                // First collision: split this leaf into a singular node,
                // the recurse inserting the string into it.
                let (h, t) = curStr.headAndTail
                self = .node([h : t.isEmpty ? .stub : .leaf(t)])
                insert(newStr)

            case .node(var dict):
                // Partial match: keep searching
                let (h, t) = newStr.headAndTail
                if var next = dict[h] {
                    // follow the common prefix if anything left
                    if !t.isEmpty {
                        next.insert(t)
                        dict[h] = next
                    }
                } else {
                    // new suffix, insert it
                    dict[h] = t.isEmpty ? .stub : .leaf(t)
                }
                self = .node(dict)
            }
        }

        func match(_ str: String) -> String? {
            switch self {
            case .stub:
                // Match iff there's no string left
                return str.isEmpty ? str : nil

            case .leaf(let leafStr):
                // Prefix match chance, return max inserted
                return leafStr.hasPrefix(str) ? leafStr : nil

            case .node(let dict):
                guard !str.isEmpty else {
                    // prefix of at least two things in the tree.  it could be that
                    // this str itself was inserted, ie. the tree has been asked
                    // to hold a subset item.  Fail.
                    return nil
                }
                let (h, t) = str.headAndTail
                guard let next = dict[h] else {
                    // next character not inserted -> fail
                    return nil
                }
                // matched a char, keep going and accumulate
                // (what are stack pages for if not using...)
                return next.match(t).flatMap { String(h) + $0 }
            }
        }
    }

    private var root: Tree = .stub

    /// Add a string to the matcher.
    ///
    /// Take care with inserted strings that are prefixes of each other.  For example:
    /// ins(aaa) ; ins(aab) ; ins(aa)
    /// Now, match(aa) will fail: we do not model that it is an end-point and so it is
    /// categorized as an ambiguous prefix of 'aaa' and 'aab'.
    ///
    /// FIx is something like making the dict key a (char, bool) indicating a terminal symbol.
    mutating func insert(_ string: String) {
        guard !string.isEmpty else { return }
        root.insert(string)
    }

    /// Test a string in the matcher.
    ///
    /// If it is a non-ambiguous prefix of an inserted string then that inserted string is returned.
    /// If it is either an ambiguous prefix or not a prefix at all then `nil` is returned.
    func match(_ string: String) -> String? {
        guard !string.isEmpty else { return nil }
        return root.match(string)
    }
}

private extension String {
    var headAndTail: (Character, String) {
        guard let firstChar = first else {
            preconditionFailure("Confused, chopping empty string")
        }
        let restStart = self.index(self.startIndex, offsetBy: 1)
        return (firstChar, String(self[restStart...]))
    }
}
