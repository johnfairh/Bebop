//
//  GatherSymbolGraph.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

enum GatherSymbolGraph {

    static func decode(moduleName: String, json: String) throws -> GatherDef {
        logDebug("Decoding main symbolgraph JSON for \(moduleName)")
        //loginfo when done
        return GatherDef(children: [], sourceKittenDict: SourceKittenDict(), kind: nil, swiftDeclaration: nil, objCDeclaration: nil, documentation: nil, localizationKey: nil, translatedDocs: nil)
    }

    static func decode(moduleName: String, otherModuleName: String, json: String) throws -> GatherDef {
        logDebug("Decoding extension symbolgraph JSON for \(moduleName) from \(otherModuleName)")
        //loginfo when done
        return GatherDef(children: [], sourceKittenDict: SourceKittenDict(), kind: nil, swiftDeclaration: nil, objCDeclaration: nil, documentation: nil, localizationKey: nil, translatedDocs: nil)
    }
}
