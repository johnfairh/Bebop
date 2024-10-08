//
//  GatherJobImport.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

// MARK: Import from SourceKitten

extension GatherJob {
    struct SourceKitten: Equatable {
        let moduleName: String
        let fileURLs: [URL]
        let defOptions: Gather.DefOptions

        func execute() throws -> GatherModulePass {
            try GatherModulePass(moduleName: moduleName,
                                 files: fileURLs.flatMap { try loadFile(url: $0)})
        }

        func loadFile(url: URL) throws -> [(pathname: String, GatherDef)] {
            logDebug("Gather: Deserializing sourcekitten JSON \(url.path)")
            let json = try String(contentsOf: url, encoding: .utf8)
            let data = try JSON.decode(json, Array<SourceKittenDict>.self)
            return data.compactMap { fileDict -> (String, GatherDef)? in
                guard let entry = fileDict.first,
                    let topDict = entry.value as? SourceKittenDict,
                    let gatherDef = GatherDef(sourceKittenDict: topDict, defOptions: defOptions) else {
                        logWarning(.wrnSknDecode, url.path, fileDict)
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
            try fileURLs
                .flatMap { try loadFile(url: $0) }
                .filter { pass in
                    moduleName == nil ||
                        (moduleName! == pass.moduleName &&
                            (passIndex == nil || passIndex! == pass.passIndex))
                }
        }

        func loadFile(url: URL) throws -> [GatherModulePass] {
            logDebug("Gather: Deserializing gather JSON \(url.path)")
            let json = try String(contentsOf: url, encoding: .utf8)
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
                        logWarning(.wrnBebopJsonDecode, url.path, fileDict)
                        return
                }

                guard Version.canImport(from: meta.version) else {
                    logWarning(.wrnBebopJsonFuture, url.path, meta.version)
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
    convenience init(_ progress: Progress) {
        self.init(moduleName: progress.moduleName,
                  passIndex: progress.passIndex,
                  imported: true,
                  files: progress.files)
    }
}
