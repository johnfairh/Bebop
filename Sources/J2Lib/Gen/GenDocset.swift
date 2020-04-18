//
//  GenDocset.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SQLite

public final class GenDocset: Configurable {
    let docsetPathOpt = PathOpt(l: "docset-path").help("PATH").hidden
    let docsetModuleNameOpt = StringOpt(l: "docset-module-name").help("MODULENAME")
    let published: Published

    /// Module Name to use for the docset - defaults to one of the source modules
    var moduleName: String {
        if let docsetModuleName = docsetModuleNameOpt.value {
            return docsetModuleName
        }
        return published.moduleNames.first!
    }

    init(config: Config) {
        published = config.published
        config.register(self)
    }

    func checkOptions() throws {
        if docsetPathOpt.configured {
            logWarning(.localized(.wrnDocsetPath))
        }
    }

    static let DOCSET_TOP = "docsets"
    static let DOCSET_SUFFIX = ".docset"

    func generate(outputURL: URL, items: [Item]) throws {
        let docsetTopURL = outputURL.appendingPathComponent(Self.DOCSET_TOP)
        let docsetDirURL = docsetTopURL.appendingPathComponent("\(moduleName)\(Self.DOCSET_SUFFIX)")
        logDebug("Docset: cleaning any old content")
        try? FileManager.default.removeItem(at: docsetTopURL)

        try copyDocs(outputURL: outputURL, docsetDirURL: docsetDirURL)
    }

    /// Copy over the files
    func copyDocs(outputURL: URL, docsetDirURL: URL) throws {
        let docsTargetURL = docsetDirURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Documents")

        logDebug("Docset: copying up docs")

        try FileManager.default.createDirectory(atPath: docsTargetURL.path, withIntermediateDirectories: true)

        // Exclude ourselves and any secondary localizations
        let skipFiles = Set([Self.DOCSET_TOP] + Localizations.shared.others.map(\.tag))

        try Glob.files(.init(outputURL.appendingPathComponent("*").path)).forEach { sourceURL in
            let filename = sourceURL.lastPathComponent
            if !skipFiles.contains(filename) {
                let targetURL = docsTargetURL.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
        }
    }
}
