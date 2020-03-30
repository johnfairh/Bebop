//
//  GatherJobSourceKitten.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// Job to get info from a set of SourceKitten source files.
//
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
