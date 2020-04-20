//
//  StderrHusher.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Posix)
import Posix
#endif

// <3 sourcekitten but sometimes we want it to stop talking...
class StderrHusher {
    internal private(set) var hushed: Bool
    private var savedStderr: Int32
    private var tmpFile: URL!

    var enabled = false

    private init() {
        hushed = false
        savedStderr = 0
    }

    func hush() {
        guard enabled else { return }
        tmpFile = FileManager.default.temporaryFileURL()
        savedStderr = dup(STDERR_FILENO)
        freopen(tmpFile.path, "a", stderr)
        hushed = true
    }

    @discardableResult
    func unhush() -> String? {
        guard hushed else { return nil }
        fclose(stderr)
        dup2(savedStderr, STDERR_FILENO)
        stderr = fdopen(STDERR_FILENO, "a")
        hushed = false
        defer { try? FileManager.default.removeItem(at: tmpFile) }
        return (try? String(contentsOf: tmpFile)) ?? ""
    }

    static var shared = StderrHusher()
}
