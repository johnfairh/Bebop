//
//  Config.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Protocol for clients that want to register options.
/// All accessible `Opt` fields are automatically found.
public protocol Configurable {
    /// Signal that all user options have been specified.
    /// Perform any in-component cross-option validation.
    func checkOptions() throws
}

extension Configurable {
    /// Do nothing by default
    func checkOptions() throws {
    }
}

/// Configuration (CLI options, config file)
///
/// 1. Components declare their options to `Config.register` during initialization.
/// 2. `Config.processOptions(cliOpts:)` applies CLI arguments and the config file.
///   Options are checked for basic syntax as they are applied, halt on first error.
/// 3. `Configurable.checkOptions()` happens.
///   Components check dependencies between their options (and validate complex yaml structures).
///   Again halt on the first error.
/// 4. XXX somebody XXX does cross-component validation.  Need to figure out what this means, beyond
///   a "warn if an option has been given that will be ignored because irrelevant"
///
/// Config is also responsible for some miscellaneous non-mission tasks:
/// * --version command
/// * --help command
/// * --debug and --quiet modes
public final class Config {
    /// Real option: where is the config file?
    private let configFileOpt = PathOpt(l: "config", help: """
        Configuration file, YAML or JSON.
        Default: .j2.yaml, .j2.json, .jazzy.yaml, .jazzy.json in current directory
        or ancestor.
        """)

    /// Command options for help / version / log-control
    private let helpOpt = CmdOpt(l: "help", help: "Show this help.")
    private let versionOpt = CmdOpt(l: "version", help: "Show the library version.")
    private let debugOpt = CmdOpt(l: "debug", y: "debug", help: "Report lots of information as the program runs.")
    private let quietOpt = CmdOpt(s: "q", l: "quiet", y: "quiet", help: "Report only serious problems.")

    private let optsParser: OptsParser

    private var configurables: [Configurable]

    /// Create a new `Config` component
    public init() {
        optsParser = OptsParser()
        configurables = []
        optsParser.addOpts(from: self)
    }

    /// Register a configurable component and its options.
    /// All the `Opt` fields from `configurable` are found and added.
    public func register(_ configurable: Configurable) {
        configurables.append(configurable)
        optsParser.addOpts(from: configurable)
    }

    /// Perform the configuration process: parse and validate the CLI arguments and config file.
    public func processOptions(cliOpts: [String]) throws {
        try optsParser.apply(cliOpts: cliOpts)

        configureLogger(report: false)

        if let configFileURL = try findConfigFile() {
            try configFileURL.checkIsFile()

            logInfo("Using config file \(configFileURL.path)")

            let configFile = try String(contentsOf: configFileURL)

            optsParser.relativePathBase = configFileURL.deletingLastPathComponent()

            try optsParser.apply(yaml: configFile)
        }

        configureLogger(report: true)

        try configurables.forEach { try $0.checkOptions() }
    }

    /// Find the config file, using a configured path or default rules.
    /// - returns: `nil` if there is no config file (legitimate)
    /// - throws: if there is a filesystem problem, or the user specifies a config file but it doesn't exist.
    func findConfigFile() throws -> URL? {
        if let userURL = configFileOpt.value {
            return userURL
        }

        let fm = FileManager.default

        // CoreFoundation vs. RealFoundation bug.
        //
        // In RF, "/".deleteLastPathComponent.standardize() => ""
        // In CF, "/".deleteLastPathComponent.standardize() => "/"  DOH
        //
        // ...so don't rely on the path going down to nothing.
        for prefix in [".j2", ".jazzy"] {
            var pathURL = URL(fileURLWithPath: fm.currentDirectoryPath)
            while true {
                for suffix in [".yaml", ".json"] {
                    let fileURL = pathURL.appendingPathComponent(prefix + suffix)
                    if fm.fileExists(atPath: fileURL.path) {
                        return fileURL
                    }
                }

                if pathURL.path == "/" {
                    break
                }
                pathURL.deleteLastPathComponent()
                pathURL.standardize()
            }
        }

        return nil
    }

    /// Handle --version / --help
    /// - returns: `true` if we executed a config command.
    public func performConfigCommand() -> Bool {
        if versionOpt.value {
            logInfo(Version.j2libVersion)
            return true
        }

        if helpOpt.value {
            logInfo("""
                    j2: Generate API documentation for Swift or Objective-C code.

                    Usage: j2 [options]

                    Options:
                    """)

            var first = true
            optsParser.allOpts
                .sorted { $0.sortKey < $1.sortKey }
                .forEach { opt in
                if first {
                    first = false
                } else {
                    logInfo("")
                }

                logInfo(" " + opt.name)

                opt.help.split(separator: "\n")
                    .map { "   " + $0 }
                    .forEach { logInfo($0) }
            }
        }
        return versionOpt.value || helpOpt.value
    }

    /// Configure the logger per options, reducing or increasing the verbosity.
    /// This is called twice because of the two-phase option-parsing so that
    /// the settings can be applied as early as possible: the `report` parameter
    /// says whether this is the second call.
    private func configureLogger(report: Bool) {
        if debugOpt.value {
            Logger.shared.activeLevels = Logger.verboseLevels

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:SS"
            Logger.shared.messagePrefix = { level in
                let timestamp = dateFormatter.string(from: Date())
                let levelStr: String
                switch level {
                case .debug: levelStr = "dbug"
                case .info: levelStr = "info"
                case .warning: levelStr = "warn"
                case .error: levelStr = "err " // 4-col align
                }
                return "[\(timestamp) \(levelStr)] "
            }
            // Everything to stdout
            Logger.shared.diagnosticLevels = []

            if report {
                logDebug("Debug enabled, version \(Version.j2libVersion)")
                if quietOpt.value {
                    logWarning("--quiet and --debug both set, ignoring --quiet")
                }
            }
        } else if quietOpt.value {
            Logger.shared.activeLevels = Logger.quietLevels
        }
    }
}
