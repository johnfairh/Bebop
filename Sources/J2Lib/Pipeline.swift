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
    /// Gather output
    case files_json
    /// Merge output
    case decls_json
    /// Produce docs
    case docs

    /// Pipeline mode is when the thing behaves fit to go in a shell pipeline -- producing parseable
    /// output only to stdout, everything else to stderr.  Used for the various json-dumping modes.
    var needsPipelineMode: Bool {
        switch self {
        case .files_json, .decls_json: return true
        case .docs: return false
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
    /// Duplicate and extension merging, conversion to more formal data structure
    public let merge: Merge
    /// Generate final docs
    public let gen: Gen

    /// User product config
    private let productsOpt = EnumListOpt<PipelineProduct>(l: "products").def([.docs])

    /// Product tracking
    private var productsToDo: Set<PipelineProduct> = []

    func testAndClearProduct(_ product: PipelineProduct) -> Bool {
        productsToDo.remove(product) != nil
    }

    var productsAllDone: Bool {
        productsToDo.isEmpty
    }

    /// Localizations
    private let defaultLocalizationOpt = StringOpt(l: "default-localization").help("LOCALIZATION")
    private let localizationsOpt = StringListOpt(l: "localizations").help("LOCALIZATION1,LOCALIZATION2,...")

    private(set) var localizations = Localizations()

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
        merge = Merge(config: config)
        gen = Gen(config: config)
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

        let gatheredData = try gather.gather(localizations: localizations)

        if testAndClearProduct(.files_json) {
            logDebug("Pipeline: producing files-json")
            logOutput(gatheredData.json)
            if productsAllDone { return }
        }

        let mergedDefs = try merge.merge(gathered: gatheredData)

        if testAndClearProduct(.decls_json) {
            logDebug("Pipeline: producing decls-json")
            logOutput(try mergedDefs.toJSON())
            if productsAllDone { return }
        }

        try gen.generate(defs: mergedDefs)
    }

    /// Callback during options processing.  Important we sort out pipeline mode now to avoid
    /// polluting stdout....
    public func checkOptions() throws {
        productsToDo = Set(productsOpt.value)
        logDebug("Pipeline: products: \(productsToDo)")
        if productsToDo.needsPipelineMode {
            Logger.shared.diagnosticLevels = Logger.allLevels
        }

        localizations = Localizations(mainDescriptor: defaultLocalizationOpt.value,
                                      otherDescriptors: localizationsOpt.value)

        logDebug("Pipeline: Main localization \(localizations.main), others \(localizations.others)")
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
