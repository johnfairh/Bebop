//
//  Gather.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

/// `Gather` generates code definition data according to rules in the config.
///
/// Fundamentally this means getting SourceKitten to run its docs pass, which means running a bunch of
/// SourceKit queries or asking libclang, for Objective C.
///
/// Gather then adds a bunch of its own garnishes to augment this basic information:
/// 1) tbd
///
/// Gather applies pathname filtering (include/exclude) from the config.
///
/// The `modules` config key allows gather to run over multiple modules to generate their documentation
/// together.  Further, it allows for multiple passes of each module: building the module multiple times with
/// different compiler flags, or for different platforms.
///
/// Gather's results can be viewed as an extended `sourcekitten doc` command -- the json for this
/// can be extracted by running j2 (XXX somehow).
///
/// The input to any of the module passes that Gather has to perform can be one of these gather.json files,
/// or an original `sourcekitten doc` json file.
///
/// XXX podspec
public struct Gather {
    /// Subcomponent for options and config YAML processing
    let opts: GatherOpts

    /// Doc comment translation
    let localize: GatherLocalize

    /// Publishing obligations
    private let published: Config.Published

    /// Create a new instance
    init(config: Config) {
        published = config.published
        opts = GatherOpts(config: config)
        localize = GatherLocalize(config: config)
    }

    /// Gather information from the configured modules.
    public func gather() throws -> [GatherModulePass] {
        try localize.initialize()

        let jobs = opts.jobs
        publishJobFacts(jobs: jobs)

        // Sometimes we discover the module name from running the job, so have
        // wait until the jobs are done to publish them.
        var moduleNames = Set<String>()

        let passes = try jobs.flatMap { job -> [GatherModulePass] in
            if jobs.count > 1 {
                logInfo(.localized(.msgGatherHeading, job.title))
            }
            let pass = try job.execute()
            pass.forEach { moduleNames.insert($0.moduleName) }
            return pass
        }

        // Publish stuff based on the passes resulting from the jobs
        opts.publishModules(names: moduleNames)

        // Garnishes
        logDebug("Gather: start doc-comment localization pass.")
        try passes.garnish(with: localize)
        logDebug("Gather: end doc-comment localization pass.")

        return passes
    }

    /// Put up things that other components need to know
    private func publishJobFacts(jobs: [GatherJob]) {
        jobs.first.flatMap { published.defaultLanguage = $0.language }

        for job in jobs {
            if let sourceDirectoryURL = job.sourceDirectoryURL {
                logDebug("Using \(sourceDirectoryURL.path) as main source directory.")
                published.sourceDirectoryURL = sourceDirectoryURL
                break
            }
        }
    }
}

/// Data from one pass of a module.
public struct GatherModulePass {
    public let moduleName: String
    public let passIndex: Int
    public let files: [(pathname: String, GatherDef)]
}


protocol GatherGarnish {
    func garnish(def: GatherDef) throws
    func initialize() throws
}

extension Array where Element == GatherModulePass {
    func garnish<T>(with: T) throws where T: GatherGarnish {
        try forEach { pass in
            try pass.files.forEach {
                func process(def: GatherDef) throws {
                    try with.garnish(def: def)
                    try def.children.forEach(process)
                }
                try process(def: $0.1)
            }
        }
    }
}
