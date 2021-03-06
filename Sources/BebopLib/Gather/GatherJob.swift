//
//  GatherJob.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// A recipe to create some passes over some module.
///
/// It's usually one pass over one module, but:
/// - podspec generates multiple passes over one module;
/// - files-json import can generate multiple passes over multiple modules
enum GatherJob : Equatable {
    case swift(title: String, job: Swift)
    case objcDirect(title: String, job: ObjCDirect)
    case sourcekitten(title: String, job: SourceKitten)
    case jsonImport(title: String, job: JSONImport)
    case symbolgraph(title: String, job: SymbolGraph)
    case podspec(title: String, job: Podspec)

    var title: String {
        switch self {
        case .swift(let title, _),
             .objcDirect(let title, _),
             .sourcekitten(let title, _),
             .jsonImport(let title, _),
             .symbolgraph(let title, _),
             .podspec(let title, _): return title
        }
    }

    var language: DefLanguage {
        switch self {
        case .swift(_, _): return .swift
        case .objcDirect(_, _): return .objc
        // Use --default-language to override this
        case .sourcekitten(_, _), .jsonImport(_, _): return .swift
        case .symbolgraph(_, _): return .swift
        case .podspec(_, _): return .swift
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

        case let .podspec(_, job):
            return try job.execute()
        }
    }

    /// Custom equatable to ignore the job title
    static func == (lhs: GatherJob, rhs: GatherJob) -> Bool {
        switch (lhs, rhs) {
        case let (.swift(_, l), .swift(_, r)): return l == r
        case let (.objcDirect(_, l), .objcDirect(_, r)): return l == r
        case let (.sourcekitten(_, l), .sourcekitten(_, r)): return l == r
        case let (.jsonImport(_, l), .jsonImport(_, r)): return l == r
        case let (.podspec(_, l), .podspec(_, r)): return l == r
        default: return false
        }
    }

    /// Init helper for swift
    init(swiftTitle: String,
         moduleName: String? = nil,
         srcDir: URL? = nil,
         buildTool: Gather.BuildTool? = nil,
         buildToolArgs: [String] = [],
         defOptions: Gather.DefOptions = .init()) {
        self = .swift(title: swiftTitle,
                      job: Swift(moduleName: moduleName,
                                 srcDir: srcDir,
                                 buildTool: buildTool,
                                 buildToolArgs: buildToolArgs,
                                 defOptions: defOptions))
    }

    #if os(macOS)
    /// Init helper for ObjCDirect
    init(objcTitle: String,
         moduleName: String,
         headerFile: URL,
         includePaths: [URL] = [],
         sdk: Gather.Sdk,
         buildToolArgs: [String] = [],
         defOptions: Gather.DefOptions = .init()) {
        self = .objcDirect(title: objcTitle,
                           job: ObjCDirect(moduleName: moduleName,
                                           headerFile: headerFile,
                                           includePaths: includePaths,
                                           sdk: sdk,
                                           buildToolArgs: buildToolArgs,
                                           defOptions: defOptions))
    }
    #endif

    /// Init helper for SourceKitten import
    init(sknImportTitle: String,
         moduleName: String,
         fileURLs: [URL],
         defOptions: Gather.DefOptions = .init()) {
        self = .sourcekitten(title: sknImportTitle,
                             job: SourceKitten(moduleName: moduleName,
                                               fileURLs: fileURLs,
                                               defOptions: defOptions))
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
         defOptions: Gather.DefOptions = .init()) {
        self = .symbolgraph(title: symbolgraphTitle,
                            job: SymbolGraph(moduleName: moduleName,
                                             searchURLs: searchURLs,
                                             buildToolArgs: buildToolArgs,
                                             sdk: sdk,
                                             target: target,
                                             defOptions: defOptions))
    }

    /// Init helper for podspec
    init(podspecTitle: String,
         moduleName: String?,
         podspecURL: URL,
         podSources: [String],
         defOptions: Gather.DefOptions = .init()) {
        self = .podspec(title: podspecTitle,
                        job: Podspec(moduleName: moduleName,
                                     podspecURL: podspecURL,
                                     podSources: podSources,
                                     defOptions: defOptions))
    }
}
