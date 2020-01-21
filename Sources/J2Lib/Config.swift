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

///
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
public final class Config {
    /// Our option -- where is the config file!
    internal let configFileOpt = PathOpt(l: "config", help: """
        Configuration file, YAML or JSON.
        Default: .j2.yaml, .j2.json, .jazzy.yaml, .jazzy.json in current directory or ancestor.
        """)

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
    public func register(configurable: Configurable) {
        configurables.append(configurable)
        optsParser.addOpts(from: configurable)
    }

    /// Perform the configuration process: parse and validate the CLI arguments and config file.
    public func processOptions(cliOpts: [String]) throws {
        try optsParser.apply(cliOpts: cliOpts)

        if let configFileURL = try findConfigFile() {
            try configFileURL.checkIsFile()

            // XXX log 'using config file...'
            print("Using config file \(configFileURL.path)")

            let configFile = try String(contentsOf: configFileURL)

            optsParser.relativePathBase = configFileURL.deletingLastPathComponent()

            try optsParser.apply(yaml: configFile)
        }

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

        for prefix in [".j2", ".jazzy"] {
            var pathURL = URL(fileURLWithPath: fm.currentDirectoryPath)
            while !pathURL.path.isEmpty {
                for suffix in [".yaml", ".json"] {
                    let fileURL = pathURL.appendingPathComponent(prefix + suffix)
                    if fm.fileExists(atPath: fileURL.path) {
                        return fileURL
                    }
                }
                pathURL.deleteLastPathComponent()
                pathURL.standardize()
            }
        }

        return nil
    }
}
