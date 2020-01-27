//
//  Gather.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//
import Foundation

public struct Gather {

    let opts: GatherOpts

    init(config: Config) {
        opts = GatherOpts(config: config)
    }

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

    public var configFileSearchStart: URL? {
        opts.configFileSearchStart
    }
}

public struct GatherModulePass {
    public let index: Int                     // serialized with each file for debug
    public let defs: [(String, GatherDef)]   // String key is the pathname
    // public let availabilityDefaults: [String] // not serialized
    // public let ignoreAvailabilityAttr: Bool   // not serialized
}

public final class GatherModule {
    public let name: String                   // serialized with each file for ease of import
    // public let merge: MergeModulePolicy       // not serialized,
    public internal(set) var passes: [GatherModulePass]

    init(name: String, pass: GatherModulePass) {
        self.name = name
        self.passes = [pass]
    }
}

public enum MergeModulePolicy {
    case yes
    case no
    case group(name: String) // should be localized map
}

public typealias GatherModules = [GatherModule]

// Serialized:
// Array [
//   Hash {
//      Version : "J2Libversion Gather output"
//      Pathname : Hash {
//         key.diagns = "...."
//         key.off : 0
//         key.len : xxx
//         key.j2.modulename: xxx
//         key.j2.configIndex: n
//         key.substructure : Array [
//            {defs}
//         ]
//      }
// ]
