//
//  Pipeline.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// A top-level type to coordinate the components.
public struct Pipeline {
    /// Options parsing and validation orchestration
    public let config: Config

    public init() {
        config = Config()
    }

    /// Build, configure, and execute a pipeline
    public func run(argv: [String]) throws {
        try config.processOptions(cliOpts: argv)

        guard !config.performConfigCommand() else {
            return
        }
    }
}

// MARK: CLI entry

public extension Pipeline {
    /// Build and run a pipeline using CLI args and status reported to stdout/stderr
    static func main(argv: [String]) -> Int32 {
        do {
            try Pipeline().run(argv: argv)
            return 0
        } catch {
            print("Error: \(error)")
            return 1
        }
    }
}
