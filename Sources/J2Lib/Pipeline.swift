//
//  Pipeline.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// The various products that the pipeline can create
enum PipelineProduct: String, CaseIterable {
    case files_json

    /// Pipeline mode is when the thing behaves fit to go in a shell pipeline -- producing parseable
    /// output only to stdout, everything else to stderr.  Used for the various json-dumping modes.
    var needsPipelineMode: Bool {
        switch self {
        case .files_json: return true
        }
    }
}

extension Sequence where Element == PipelineProduct {
    var needsPipelineMode: Bool {
        reduce(false, { result, next in result || next.needsPipelineMode })
    }
}

/// A top-level type to coordinate the components.
public final class Pipeline: Configurable {
    /// Options parsing and validation orchestration
    public let config: Config
    /// Info gathering and garnishing
    public let gather: Gather

    /// User product config
    private let productsOpt = EnumListOpt<PipelineProduct>(l: "products")

    /// Product tracking
    private var productsToDo: Set<PipelineProduct> = []

    func testAndClearProduct(_ product: PipelineProduct) -> Bool {
        productsToDo.remove(product) != nil
    }

    var productsAllDone: Bool {
        productsToDo.isEmpty
    }

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
        gather = Gather(config: config)
        config.register(self)
    }

    /// Build, configure, and execute a pipeline according to `argv` and
    /// any config file.
    public func run(argv: [String] = []) throws {
        try config.processOptions(cliOpts: argv)

        Resources.logInitializationProgress()

        guard !config.performConfigCommand() else {
            return
        }

        let gatheredModules = try gather.gather()

        if testAndClearProduct(.files_json) {
            logDebug("Pipeline: producing files-json")
            logOutput(gatheredModules.json)
            if productsAllDone { return }
        }
    }

    /// Callback during options processing.  Important we sort out pipeline mode now to avoid
    /// polluting stdout....
    public func checkOptions() throws {
        productsToDo = Set(productsOpt.value)
        logDebug("Pipeline: products: \(productsToDo)")
        if productsToDo.needsPipelineMode {
            Logger.shared.diagnosticLevels = Logger.allLevels
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
            // Linux workaround or some bug here, if I call `localizedDescription` on
            // one of my errors through whatever type then it segfaults.
            logError(error.description)
            return 1
        } catch {
            logError(error.localizedDescription)
            return 1
        }
    }
}
