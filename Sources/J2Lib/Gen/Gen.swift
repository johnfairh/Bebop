//
//  Gen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Mustache

public struct Gen: Configurable {
    let outputOpt = PathOpt(s: "o", l: "output").help("PATH").def("docs")
    let cleanOpt = BoolOpt(s: "c", l: "clean")

    var outputURL: URL {
        outputOpt.value!
    }

    public init(config: Config) {
        Mustache.MustacheLogger = { logWarning("Mustache: \($0)") }
        config.register(self)
    }

    public func generate(defs: [DeclDef]) throws {
        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            try FileManager.default.removeItem(at: outputURL)
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        try defs.forEach { try self.createPage(def: $0) }
    }

    func createPage(def: DeclDef) throws {
        let url = outputURL.appendingPathComponent("\(def.name).html")
        let content = Data(base64Encoded: def.name)!
        try content.write(to: url)
    }
}
