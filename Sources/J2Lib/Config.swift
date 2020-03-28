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
protocol Configurable {
    /// Signal that all user options have been specified.
    /// Perform any in-component cross-option validation.
    func checkOptions(published: Config.Published) throws
}

extension Configurable {
    /// Do nothing by default
    func checkOptions(published: Config.Published) throws {
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
///
/// Config is also responsible for some miscellaneous non-mission tasks:
/// * --version command
/// * --help command
/// * --debug and --quiet modes
public final class Config {
    /// Real option: where is the config file?
    private let configFileOpt = PathOpt(l: "config").help("PATH")

    /// Command options for help / version / log-control
    private let helpOpt = CmdOpt(l: "help", yaml: .none)
    private let versionOpt = CmdOpt(l: "version", yaml: .none)
    private let debugOpt = CmdOpt(l: "debug")
    private let quietOpt = CmdOpt(l: "quiet")

    private let optsParser: OptsParser

    /// Client stuff
    private var configurables: [Configurable]
    private var srcDirOpt: PathOpt?

    /// Published options -- publish during register, read during checkOptions
    /// All slightly broken abstractions....
    final class Published {
        // Published by Config
        public var configRelativePathBaseURL: URL?
        // Published by GatherOpts
        public var sourceDirectoryURL: URL?
        // Published by GatherOpts
        public var moduleGroupPolicy = [String : ModuleGroupPolicy]()
        public var moduleNames: [String] {
            moduleGroupPolicy.keys.sorted(by: <)
        }
        public var isMultiModule: Bool {
            moduleGroupPolicy.count > 1
        }
        // Published by GatherOpts
        public var defaultLanguage = DefLanguage.swift
        // Published by GenCopyright
        public var authorName: Localized<String>?
        // Published by GenSite
        public var childItemStyle: ChildItemStyle!
        // Published by MergeFilter
        public var excludedAclList = ""
        // Published b Group
        public var sourceOrderDefs = false
    }
    let published = Published()

    /// Create a new `Config` component
    public init() {
        optsParser = OptsParser()
        configurables = []
        srcDirOpt = nil
        optsParser.addOpts(from: self)
    }

    /// Register a configurable component and its options.
    /// All the `Opt` fields from `configurable` are found and added.
    func register(_ configurable: Configurable) {
        configurables.append(configurable)
        optsParser.addOpts(from: configurable)
    }

    /// Record the srcDir option -- horrendous kludge to locate the config file part-way through
    /// options processing...
    func registerSrcDirOpt(_ opt: PathOpt) {
        srcDirOpt = opt
    }

    /// Perform the configuration process: parse and validate the CLI arguments and config file.
    public func processOptions(cliOpts: [String]) throws {
        var optsError: Swift.Error? = nil

        do {
            try optsParser.apply(cliOpts: cliOpts)
        } catch {
            optsError = error
        }

        if versionOpt.value || helpOpt.value {
            return
        }

        if let optsError = optsError {
            throw optsError
        }

        configureLogger(report: false)
        // More spaghetti.  We normally want to dump the config file location to stdout
        // but mustn't if we're in pipeline mode, but we don't know if we're in pipeline
        // mode until we've read the config file, but we want to display the config
        // file location if there's an error parsing the config file.
        // The 'pipeline mode' changes happen during the #1 callback, so logging this
        // on exit should work.
        var infoLog: String? = nil
        defer { infoLog.flatMap { logInfo($0) } }

        if let configFileURL = try findConfigFile() {
            try configFileURL.checkIsFile()

            infoLog = .localized(.msgConfigFile, configFileURL.path)

            let configFile = try String(contentsOf: configFileURL)
            let configFileDir = configFileURL.deletingLastPathComponent()
            optsParser.relativePathBase = configFileDir
            published.configRelativePathBaseURL = configFileDir

            try optsParser.apply(yaml: configFile)
        }

        configureLogger(report: true)

        try configurables.forEach { try $0.checkOptions(published: published) } // #1
    }

    /// Find the config file, using a configured path or default rules.
    /// - returns: `nil` if there is no config file (legitimate)
    /// - throws: if there is a filesystem problem, or the user specifies a config file but it doesn't exist.
    func findConfigFile() throws -> URL? {
        if let userURL = configFileOpt.value {
            return userURL
        }

        let fm = FileManager.default

        let initialSearchPath: String
        if let srcDirURL = srcDirOpt?.value {
            initialSearchPath = srcDirURL.path
        } else {
            initialSearchPath = fm.currentDirectoryPath
        }

        // CoreFoundation vs. RealFoundation bug.
        //
        // In RF, "/".deleteLastPathComponent.standardize() => ""
        // In CF, "/".deleteLastPathComponent.standardize() => "/"  DOH
        //
        // ...so don't rely on the path going down to nothing.
        for prefix in [".j2", ".jazzy"] {
            var pathURL = URL(fileURLWithPath: initialSearchPath)
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
        }

        if helpOpt.value {
            logInfo(.localized(.msgHelpIntro))

            var first = true
            optsParser.allOpts
                .sorted { $0.sortKey < $1.sortKey }
                .forEach { opt in
                if first {
                    first = false
                } else {
                    logInfo("")
                }

                logInfo(" " + opt.name(usage: true))

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
            // Everything to stderr
            Logger.shared.diagnosticLevels = Logger.allLevels

            if report {
                logDebug("Debug enabled, version \(Version.j2libVersion)")
                if quietOpt.value {
                    logWarning(.localized(.wrnQuietDebug))
                }
            }
        } else if quietOpt.value {
            Logger.shared.activeLevels = Logger.quietLevels
        }
    }
}
