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

    func generate(outputURL: URL, items: [Item]) throws {

    }
}
