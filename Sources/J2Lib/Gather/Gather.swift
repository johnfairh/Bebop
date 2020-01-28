//
//  Gather.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

/// `Gather` is responsible for generating code definition data according to rules in the config.
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

    /// Create a new instance
    init(config: Config) {
        opts = GatherOpts(config: config)
    }

    /// Gather information from the configured modules.
    public func gather() throws -> GatherModules {
        // have opts separately figure out the module->mergepolicy.
        // that way we don't get incredible tramp data with mergepolicy.
        // we can't have it figure out module names because of implicit
        // top-level, and multi-module-import.
        // ooh no, it has an API mapping module-name to merge-policy, defaults
        // to something for unknown.  Fine.
        let passData = try opts.jobs.map { try $0.execute() }.flatMap { $0 }

        // include/exclude filtering

        var moduleDict = [String: GatherModule]()

        passData.forEach { pass in
            if let module = moduleDict[pass.0] {
                module.passes.append(pass.1)
            } else {
                moduleDict[pass.0] = GatherModule(name: pass.0, pass: pass.1)
            }
        }

        let modules = moduleDict.values

        // Garnishes here

        return GatherModules(modules)
    }
}

/// Data from one pass of a module.
public struct GatherModulePass {
    public let index: Int
    public let defs: [(pathname: String, GatherDef)]
    // public let availabilityDefaults: [String] // not serialized
    // public let ignoreAvailabilityAttr: Bool   // not serialized
}

/// Data from all passes of a module.
public final class GatherModule {
    public let name: String
    // public let merge: MergeModulePolicy       // not serialized,
    public internal(set) var passes: [GatherModulePass]

    init(name: String, pass: GatherModulePass) {
        self.name = name
        self.passes = [pass]
    }
}

/// Data from all gathered modules.
public struct GatherModules {
    public let modules: [GatherModule]

    init<T: Sequence>(_ modules: T) where T.Element == GatherModule {
        self.modules = Array(modules)
    }
}

//public enum MergeModulePolicy {
//    case yes
//    case no
//    case group(name: String) // should be localized map
//}