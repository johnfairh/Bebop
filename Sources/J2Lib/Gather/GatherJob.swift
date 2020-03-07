//
//  GatherJob.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// A recipe to create one pass over a module.
///
/// In fact that's a lie because "import a gather.json" is also a job that can vend multiple modules and passes.
/// That may be a modelling error, tbd pending implementation of import....
enum GatherJob : Equatable {
    case swift(title: String, job: Swift)
    case objcDirect(title: String, job: ObjCDirect)

    var title: String {
        switch self {
        case .swift(let title, _): return title
        case .objcDirect(let title, _): return title
        }
    }

    func execute() throws -> [GatherModulePass] {
        logDebug("Gather: starting job \(self)")
        defer { logDebug("Gather: finished job") }

        switch self {
        case let .swift(_, job):
            return try [job.execute()]

        case let .objcDirect(_, job):
            #if os(macOS)
            return try [job.execute()]
            #else
            return []
            #endif
        }
    }

    /// Custom equatable to ignore the job title
    static func == (lhs: GatherJob, rhs: GatherJob) -> Bool {
        switch (lhs, rhs) {
        case let (.swift(_, l), .swift(_, r)): return l == r
        case let (.objcDirect(_, l), .objcDirect(_, r)): return l == r
        default: return false
        }
    }

    /// Init helper for swift
    init(swiftTitle: String,
         moduleName: String? = nil,
         srcDir: URL? = nil,
         buildTool: Gather.BuildTool? = nil,
         buildToolArgs: [String] = [],
         availability: Gather.Availability = Gather.Availability()) {
        self = .swift(title: swiftTitle,
                      job: Swift(moduleName: moduleName,
                                 srcDir: srcDir,
                                 buildTool: buildTool,
                                 buildToolArgs: buildToolArgs,
                                 availability: availability))
    }

    #if os(macOS)
    /// Init helper for ObjCDirect
    init(objcTitle: String,
         moduleName: String,
         headerFile: URL,
         includePaths: [URL] = [],
         sdk: Gather.Sdk,
         buildToolArgs: [String] = [],
         availability: Gather.Availability = Gather.Availability()) {
        self = .objcDirect(title: objcTitle,
                           job: ObjCDirect(moduleName: moduleName,
                                           headerFile: headerFile,
                                           includePaths: includePaths,
                                           sdk: sdk,
                                           buildToolArgs: buildToolArgs,
                                           availability: availability))
    }
    #endif
}
