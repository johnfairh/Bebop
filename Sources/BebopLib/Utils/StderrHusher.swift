//
//  StderrHusher.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

@preconcurrency import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Posix)
@preconcurrency import Posix
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
        return (try? String(contentsOf: tmpFile, encoding: .utf8)) ?? ""
    }

    static nonisolated(unsafe) var shared = StderrHusher()
}
