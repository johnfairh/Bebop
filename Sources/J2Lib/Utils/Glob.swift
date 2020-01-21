//
//  Glob.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Namespace for a set of utilities to deal with matching files and directories in a shell-globbish way.
/// These are implemented using libc primitives.
public enum Glob {

    /// A boxed string to make code a little more obvious
    public struct Pattern: ExpressibleByStringLiteral, CustomStringConvertible, Equatable {
        public let value: String
        public init(_ pattern: String) { self.init(stringLiteral: pattern) }
        public init(stringLiteral value: String) { self.value = value }
        public var description: String { return value }
    }

    /// Return the list of files that match a pattern.
    ///
    /// Might be that this should return `URL`s, have to see how we use it exactly.
    ///
    /// - parameter pattern: A pattern that may contain simple shell globs, `*` and `?`.
    public static func files(_ pattern: Pattern) -> [String] {
        var globData = glob_t()

        // required even if glob(3) fails
        defer { globfree(&globData) }

        let rc = glob(pattern.value, GLOB_NOCHECK, nil, &globData)

        guard rc == 0, globData.gl_pathv != nil else {
            // This means we ran out of memory or something equally unlikely.
            // XXX warn
            return []
        }

        var paths = [String]()

        for i in 0..<Int(globData.gl_matchc) {
            let charStar = globData.gl_pathv![i]
            if let cStr = charStar {
                paths.append(String(cString: cStr))
            } else {
                // This is also not ideal and suggests libc is messed up...
                // XXX warn
            }
        }

        return paths
    }

    /// Determine if a path matches a glob pattern.
    ///
    /// Slashes are not treated specially: "/f*/bar" will match "/foo/baz/bar", for example.
    public static func match(_ pattern: Pattern, path: String) -> Bool {
        let rc = fnmatch(pattern.value, path, 0)

        if rc != 0 && rc != FNM_NOMATCH {
            // XXX warn
        }

        return rc == 0
    }
}
