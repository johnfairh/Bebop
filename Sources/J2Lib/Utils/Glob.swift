//
//  Glob.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

//
// Careful here with Darwin/Linux differences
//

/// Namespace for a set of utilities to deal with matching files and directories in a shell-globbish way.
/// These are implemented using libc primitives.
enum Glob {
    /// A boxed string to make code a little more obvious
    struct Pattern: ExpressibleByStringLiteral, Equatable, CustomStringConvertible {
        public let value: String
        public init(_ pattern: String) { self.init(stringLiteral: pattern) }
        public init(stringLiteral value: String) { self.value = value }
        var description: String { value }

        static var all = Self("*")
    }

    /// Return the list of files that match a pattern.
    ///
    /// - parameter pattern: A pattern that may contain simple shell globs, `*` and `?`.
    static func files(_ pattern: Pattern) -> [URL] {
        var globData = glob_t()

        // required even if glob(3) fails
        defer { globfree(&globData) }

        let rc = glob(pattern.value, 0, nil, &globData)

        guard rc != GLOB_NOMATCH else {
            return []
        }

        guard rc == 0, globData.gl_pathv != nil else {
            // This means we ran out of memory or something equally unlikely.
            logWarning(.localized(.wrnGlobErrno, pattern, errno, strerror_s()))
            return []
        }

        var paths = [URL]()

        for i in 0..<Int(globData.gl_pathc) {
            let charStar = globData.gl_pathv![i]
            if let cStr = charStar {
                paths.append(URL(fileURLWithPath: String(cString: cStr)))
            } else {
                // This is also not ideal and suggests libc is messed up...
                logWarning(.localized(.wrnGlobPattern, pattern))
            }
        }

        return paths
    }

    /// Determine if a path matches a glob pattern.
    ///
    /// Slashes are not treated specially: "/f*/bar" will match "/foo/baz/bar", for example.
    static func match(_ pattern: Pattern, path: String) -> Bool {
        let rc = fnmatch(pattern.value, path, 0)

        if rc != 0 && rc != FNM_NOMATCH {
            logWarning(.localized(.wrnFnmatchErrno, pattern, path, errno, strerror_s()))
        }

        return rc == 0
    }
}

// wimping out of strerror_r cos we're single-threaded...
private func strerror_s() -> String {
    guard let strerror = strerror(errno) else {
        return "(?)"
    }
    return String(cString: strerror)
}

extension URL {
    /// Return all files in this directory URL that match the pattern[s]
    func filesMatching(_ patterns: Glob.Pattern...) -> [URL] {
        patterns.flatMap { pat -> [URL] in
            let globPath = appendingPathComponent(pat.value).path
            return Glob.files(Glob.Pattern(globPath))
        }
    }
}
