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

    init(config: Config) {
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
