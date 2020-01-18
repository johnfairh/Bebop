//
//  Regexp.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// A concise wrapper of regular expression string operators based on perl etc.
//

/// A concise version of the usual regular expression flags
public enum RegexpOptions {
    /// case insensitive
    case i
    /// comments
    case x
    /// dot matches line-endings
    case s
    /// ^$ match lines not text
    case m
    /// unicode-correct \b -- maybe this should always be on?
    case w

    var toFoundation: NSRegularExpression.Options {
        switch self {
        case .i: return .caseInsensitive
        case .x: return .allowCommentsAndWhitespace
        case .s: return .dotMatchesLineSeparators
        case .m: return .anchorsMatchLines
        case .w: return .useUnicodeWordBoundaries
        }
    }
}

extension Array where Element == RegexpOptions {
    var toFoundation: NSRegularExpression.Options {
        reduce([], { opts, opt in opts.union(opt.toFoundation) })
    }
}

extension String {
    /// Split using a regular expression.
    ///
    /// Returns the pieces of the string, not including separators.  Zero-length pieces are not returned.
    ///
    /// - Parameter on: regexp to split on
    /// - Parameter options: regexp options
    func re_split(_ separator: String, options: [RegexpOptions] = []) -> [Substring] {
        let re = try! NSRegularExpression(pattern: separator, options: options.toFoundation)

        // Find separator spans
        let sepRanges = re.matches(in: self, range: nsRange).map { Range($0.range, in: self)! }

        var nextIndex = startIndex
        var itemRanges = [Range<Index>]()

        // Add the range before each separator
        sepRanges.forEach { separator in
            itemRanges.append(nextIndex..<separator.lowerBound)
            nextIndex = separator.upperBound
        }
        // Add the range between final separator and end-of-string
        itemRanges.append(nextIndex..<endIndex)

        return itemRanges.filter({ !$0.isEmpty }).map { self[$0] }
    }

    /// Search & replace using a regular expression
    ///
    /// - Parameter searchPattern: pattern to search for
    /// - Parameter template: template to replace with ($n for capture groups)
    /// - Parameter options: regex options
    func re_sub(_ searchPattern: String, with template: String, options: [RegexpOptions] = []) -> String {
        let re = try! NSRegularExpression(pattern: searchPattern, options: options.toFoundation)
        return re.stringByReplacingMatches(in: self, range: nsRange, withTemplate: template)
    }

    /// Check if the string matches a regular expression.
    ///
    /// See `String.re_match` to find out what is in the match.
    /// 
    /// - Parameter pattern: pattern to match against
    /// - Parameter options: regex options
    func re_isMatch(_ pattern: String, options: [RegexpOptions] = []) -> Bool {
        re_match(pattern, options: options) != nil
    }

    /// Regex match result data
    ///
    /// This is more than an array of strings because of named capture groups
    public struct ReMatchResult {
        private let string: String
        private let textCheckingResult: NSTextCheckingResult

        fileprivate init(string: String, textCheckingResult: NSTextCheckingResult) {
            self.string = string
            self.textCheckingResult = textCheckingResult
        }

        /// Get the capture group contents.  0 is the entire match.
        public subscript(rangeIndex: Int) -> Substring {
            let nsRange = textCheckingResult.range(at: rangeIndex)
            return string.from(nsRange: nsRange)
        }

        /// Get the contents of a named capture group
        public subscript(captureGroupName: String) -> Substring {
            let nsRange = textCheckingResult.range(withName: captureGroupName)
            return string.from(nsRange: nsRange)
        }
    }

    /// Match the regular expression against the string and return info about the first match
    ///
    /// - parameter pattern: pattern to match against
    /// - parameter options: regex options
    /// - returns: `ReMatchResult` object that can be queried for capture groups, or `nil` if there is no match
    func re_match(_ pattern: String, options: [RegexpOptions] = []) -> ReMatchResult? {
        let re = try! NSRegularExpression(pattern: pattern, options: options.toFoundation)
        guard let match = re.firstMatch(in: self, range: nsRange) else {
            return nil
        }
        return ReMatchResult(string: self, textCheckingResult: match)
    }

    /// Feel like this exists somewhere already...
    private var nsRange: NSRange {
        NSRange(startIndex..<endIndex, in: self)
    }

    /// And this too...
    private func from(nsRange: NSRange) -> Substring {
        self[Range(nsRange, in: self)!]
    }
}
