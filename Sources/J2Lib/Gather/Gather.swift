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
public final class Gather: Configurable {
    /// Subcomponent for options and config YAML processing
    private let opts: GatherOpts

    /// Doc comment translation
    private let localize: GatherLocalize

    /// Publishing obligations - we have to retain the writable version because
    /// we publish module info much later than the config phase.
    private var publish: PublishStore!

    /// Create a new instance
    public init(config: Config) {
        opts = GatherOpts(config: config)
        localize = GatherLocalize(config: config)
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        self.publish = publish
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
                logInfo(.msgGatherHeading, job.title)
            }
            let pass = try job.execute()
            pass.forEach { moduleNames.insert($0.moduleName) }
            return pass
        }

        // Publish stuff based on the passes resulting from the jobs
        publish.modules = opts.modulesToPublish(names: moduleNames)

        // Garnishes
        logDebug("Gather: start doc-comment localization pass.")
        try localize.walk(passes)
        logDebug("Gather: end doc-comment localization pass.")

        return passes
    }

    /// Put up things that other components need to know
    private func publishJobFacts(jobs: [GatherJob]) {
        jobs.first.flatMap { publish.defaultLanguage = $0.language }
    }
}

/// Data from one pass of a module.
public struct GatherModulePass {
    public let moduleName: String
    public let passIndex: Int
    public let imported: Bool
    public let files: [(pathname: String, GatherDef)]
}

protocol GatherDefVisitor {
    func visit(def: GatherDef, parents: [GatherDef]) throws
}

extension GatherDefVisitor {
    /// Visit an item followed by its children.  Depth-first, preorder.
    func walk(_ def: GatherDef, parents: [GatherDef] = []) throws {
        try visit(def: def, parents: parents)
        try walk(def.children, parents: parents + [def])
    }

    /// Visit a list of items and their children
    func walk<S>(_ defs: S, parents: [GatherDef] = []) throws where S: Sequence, S.Element == GatherDef {
        try defs.forEach { try walk($0, parents: parents) }
    }

    /// Visit a list of passes
    func walk(_ passes: [GatherModulePass]) throws {
        try passes.forEach { pass in
            guard !pass.imported else { return }
            try pass.files.forEach {
                try walk($0.1)
            }
        }
    }
}
