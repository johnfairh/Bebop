//
//  FormatAbstracts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// Custom abstracts

final class FormatAbstracts: Configurable {
    let customAbstractsOpt = GlobListOpt(l: "custom-abstracts").help("FILEPATHGLOB1,FILEPATHGLOB2,...")
    let customAbstractOverwriteOpt = BoolOpt(l: "custom-abstract-overwrite")

    let abstractAliasOpt: AliasOpt

    init(config: Config) {
        abstractAliasOpt = AliasOpt(realOpt: customAbstractsOpt, l: "abstract")
        config.register(self)
    }

    func attach(items: [Item]) {
        
    }
}
