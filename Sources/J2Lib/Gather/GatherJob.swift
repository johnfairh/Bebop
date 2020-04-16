//
//  GatherJob.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// A recipe to create one pass over a module.
///
/// In fact that's a lie because "import a gather.json" is also a job that can vend multiple modules and passes.
/// That may be a modelling error, tbd pending implementation of import....
enum GatherJob : Equatable {
    case swift(title: String, job: Swift)
    case objcDirect(title: String, job: ObjCDirect)
    case sourcekitten(title: String, job: SourceKitten)
    case jsonImport(title: String, job: JSONImport)
    case symbolgraph(title: String, job: SymbolGraph)

    var title: String {
        switch self {
        case .swift(let title, _),
             .objcDirect(let title, _),
             .sourcekitten(let title, _),
             .jsonImport(let title, _),
             .symbolgraph(let title, _): return title
        }
    }

    var language: DefLanguage {
        switch self {
        case .swift(_, _): return .swift
        case .objcDirect(_, _): return .objc
        // Use --default-language to override this
        case .sourcekitten(_, _), .jsonImport(_, _): return .swift
        case .symbolgraph(_, _): return .swift
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

        case let .sourcekitten(_, job):
            return try [job.execute()]

        case let .jsonImport(_, job):
            return try job.execute()

        case let .symbolgraph(_, job):
            return try [job.execute()]
        }
    }

    /// Custom equatable to ignore the job title
    static func == (lhs: GatherJob, rhs: GatherJob) -> Bool {
        switch (lhs, rhs) {
        case let (.swift(_, l), .swift(_, r)): return l == r
        case let (.objcDirect(_, l), .objcDirect(_, r)): return l == r
        case let (.sourcekitten(_, l), .sourcekitten(_, r)): return l == r
        case let (.jsonImport(_, l), .jsonImport(_, r)): return l == r
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

    /// Init helper for SourceKitten import
    init(sknImportTitle: String,
         moduleName: String,
         fileURLs: [URL],
         availability: Gather.Availability = Gather.Availability()) {
        self = .sourcekitten(title: sknImportTitle,
                             job: SourceKitten(moduleName: moduleName,
                                               fileURLs: fileURLs,
                                               availability: availability))
    }

    /// Init helper for gather import
    init(importTitle: String,
         moduleName: String?,
         passIndex: Int?,
         fileURLs: [URL]) {
        self = .jsonImport(title: importTitle,
                           job: JSONImport(moduleName: moduleName,
                                           passIndex: passIndex,
                                           fileURLs: fileURLs))
    }

    /// Init helper for symbolgraph import
    init(symbolgraphTitle: String,
         moduleName: String,
         searchURLs: [URL],
         buildToolArgs: [String],
         sdk: Gather.Sdk,
         target: String,
         availability: Gather.Availability) {
        self = .symbolgraph(title: symbolgraphTitle,
                            job: SymbolGraph(moduleName: moduleName,
                                             searchURLs: searchURLs,
                                             buildToolArgs: buildToolArgs,
                                             sdk: sdk,
                                             target: target,
                                             availability: availability))
    }
}
