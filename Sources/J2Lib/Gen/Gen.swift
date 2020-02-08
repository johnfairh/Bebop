//
//  Gen.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// `Gen` produces docs output data from an `Item` forest.
///
/// tbd whether we need the pagegen / sitegen split - just stubs really
public struct Gen: Configurable {
    let outputOpt = PathOpt(s: "o", l: "output").help("PATH").def("docs")
    let cleanOpt = BoolOpt(s: "c", l: "clean")

    var outputURL: URL {
        outputOpt.value!
    }

    let themes: Themes

    public init(config: Config) {
        themes = Themes(config: config)
        config.register(self)
    }

    public func generate(defs: [Item]) throws {
        let theme = try themes.select()

        if cleanOpt.value {
            logDebug("Gen: Cleaning output directory \(outputURL.path)")
            try FileManager.default.removeItem(at: outputURL)
        }

        logDebug("Gen: Creating output directory \(outputURL.path)")
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        try defs.forEach { def in
            let url = outputURL.appendingPathComponent("\(def.name).\(theme.fileExtension)")
            let mustacheData = ["name" : def.name]
            logDebug("Gen: Rendering template \(def.name)")
            let rendered = try theme.renderTemplate(data: mustacheData)
            logDebug("Gen: Creating \(url.path)")
            try rendered.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
