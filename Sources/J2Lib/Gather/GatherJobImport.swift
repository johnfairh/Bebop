//
//  GatherJobImport.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Import from SourceKitten

extension GatherJob {
    struct SourceKitten: Equatable {
        let moduleName: String
        let fileURLs: [URL]
        let availability: Gather.Availability

        func execute() throws -> GatherModulePass {
            try GatherModulePass(moduleName: moduleName,
                                 passIndex: 0,
                                 imported: false,
                                 files: fileURLs.flatMap { try loadFile(url: $0)})
        }

        func loadFile(url: URL) throws -> [(pathname: String, GatherDef)] {
            logDebug("Gather: Deserializing sourcekitten JSON \(url.path)")
            let json = try String(contentsOf: url)
            let data = try JSON.decode(json, Array<SourceKittenDict>.self)
            return data.compactMap { fileDict -> (String, GatherDef)? in
                guard let entry = fileDict.first,
                    let topDict = entry.value as? SourceKittenDict,
                    let gatherDef = GatherDef(sourceKittenDict: topDict,
                                              parentNameComponents: [],
                                              file: nil,
                                              availability: availability) else {
                        logWarning(.localized(.wrnSknDecode, fileDict))
                        return nil
                }
                return (entry.key, gatherDef)
            }
        }
    }
}

// MARK: Import from Files-JSON

/// This is more complicated than the SourceKitten version because it contains all kinds of garnished
/// information that needs to be decoded into the actual data structures, and because the JSON files
/// can contain info about multiple passes over multiple modules.
extension GatherJob {
    struct JSONImport: Equatable {
        let moduleName: String?
        let passIndex: Int?
        let fileURLs: [URL]

        func execute() throws -> [GatherModulePass] {
            let allPasses = try fileURLs.flatMap { try loadFile(url: $0) }
            guard let moduleName = moduleName else {
                return allPasses
            }
            let modulePasses = allPasses.filter { $0.moduleName == moduleName }
            guard let passIndex = passIndex else {
                return modulePasses
            }
            return modulePasses.filter { $0.passIndex == passIndex }
        }

        func loadFile(url: URL) throws -> [GatherModulePass] {
            logDebug("Gather: Deserializing gather JSON \(url.path)")
            let json = try String(contentsOf: url)
            let data = try JSON.decode(json, Array<SourceKittenDict>.self)

            var passes = [GatherModulePass]()
            var progress: Progress? = nil

            func finishProgress() {
                progress.flatMap { passes.append(GatherModulePass($0)) }
                progress = nil
            }

            data.forEach { fileDict in
                guard fileDict.count == 1,
                    let first = fileDict.first,
                    var rootDict = first.value as? SourceKittenDict,
                    let meta = rootDict.removeMetadata() else {
                        logWarning("Can't decode portion of \(url): \(fileDict)")
                        return
                }

                guard Version.canImport(from: meta.version) else {
                    logWarning("Can't import files-json \(url), j2 version \(meta.version) is too advanced.")
                    return
                }

                if let progress = progress,
                    progress.moduleName != meta.moduleName || progress.passIndex != meta.pass {
                    finishProgress()
                }
                if progress == nil {
                    logDebug("Gather: found gather JSON for \(meta.moduleName) pass \(meta.pass)")
                    progress = Progress(moduleName: meta.moduleName, passIndex: meta.pass, files: [])
                }
                progress?.files.append((first.key, GatherDef(filesDict: rootDict)))
            }
            finishProgress()
            return passes
        }
    }
}

fileprivate struct Progress {
    let moduleName: String
    let passIndex: Int
    var files: [(String, GatherDef)]
}

fileprivate extension GatherModulePass {
    init(_ progress: Progress) {
        self.moduleName = progress.moduleName
        self.passIndex = progress.passIndex
        self.imported = true
        self.files = progress.files
    }
}
