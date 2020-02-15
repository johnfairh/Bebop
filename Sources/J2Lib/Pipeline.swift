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
    /// PageGen output
    case docs_summary_json
    /// SiteGen output
    case docs_json
    /// Produce docs
    case docs

    /// Pipeline mode is when the thing behaves fit to go in a shell pipeline -- producing parseable
    /// output only to stdout, everything else to stderr.  Used for the various json-dumping modes.
    var needsPipelineMode: Bool {
        switch self {
        case .files_json, .decls_json, .docs_summary_json, .docs_json: return true
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
    /// Create sections and guides, sort topics
    public let group: Group
    /// Assign URLs and render autolinked html, markdown
    public let format: Format
    /// Flatten and consolidate docs
    public let genPages: GenPages
    /// Generate final site
    public let genSite: GenSite

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
        group = Group(config: config)
        format = Format(config: config)
        genPages = GenPages(config: config)
        genSite = GenSite(config: config)
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

        let gatheredData = try gather.gather()

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

        let groupedDefs = try group.group(merged: mergedDefs)

        let formattedItems = try format.format(items: groupedDefs)

        let genData = try genPages.generatePages(items: formattedItems)

        if testAndClearProduct(.docs_summary_json) {
            logDebug("Pipeline: producing docs-summary-json")
            logOutput(try genData.toJSON())
            if productsAllDone { return }
        }

        if testAndClearProduct(.docs_json) {
            logDebug("Pipeline: producing docs-json")
            let output = try genSite.generateJSON(genData: genData)
            logOutput(output)
            if productsAllDone { return }
        }

        logDebug("Pipeline: generating site")
        try genSite.generateSite(genData: genData)
    }

    /// Callback during options processing.  Important we sort out pipeline mode now to avoid
    /// polluting stdout....
    public func checkOptions(published: Config.Published) throws {
        productsToDo = Set(productsOpt.value)
        logDebug("Pipeline: products: \(productsToDo)")
        if productsToDo.needsPipelineMode {
            Logger.shared.diagnosticLevels = Logger.allLevels
        }

        let localizations = Localizations(mainDescriptor: defaultLocalizationOpt.value,
                                          otherDescriptors: localizationsOpt.value)

        logDebug("Pipeline: Main localization \(localizations.main), others \(localizations.others)")
        Localizations.shared = localizations
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
            logError(String(describing: error))
            return 1
        }
    }
}
