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

    /// Set up a new pipeline.
    /// - parameter logger: Optional `Logger` to use for logging messages.
    ///   Some settings in it will be overwritten if `--quiet` or `--debug` are passed
    ///   to `run(argv:)`.
    public init(logger: Logger? = nil) {
        if let logger = logger {
            Logger.shared = logger
        }

        Resources.initialize()

        config = Config()
    }

    /// Build, configure, and execute a pipeline according to `argv` and
    /// any config file.
    public func run(argv: [String] = []) throws {
        try config.processOptions(cliOpts: argv)

        Resources.logInitializationProgress()

        guard !config.performConfigCommand() else {
            return
        }
    }
}

// MARK: CLI entry

public extension Pipeline {
    /// Build and run a pipeline using CLI args and status reported to stdout/stderr
    static func main(argv: [String]) -> Int32 {
        Logger.shared.messagePrefix = { level in
            switch level {
            // are these supposed to be localized?
            case .debug: return "j2: debug: "
            case .info: return ""
            case .warning: return "j2: warning: "
            case .error: return "j2: error: "
            }
        }
        do {
            try Pipeline().run(argv: argv)
            return 0
        } catch let error as Error {
            logError(error.description)
            return 1
        } catch {
            logError(error.localizedDescription)
            return 1
        }
    }
}
