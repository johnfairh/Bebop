//
//  GenThemesJazzy.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Compatibility mode for jazzy themes - get at least 95% of the way to rendering into an existing
/// jazzy theme.  Design choice was to completely redo the mustache data design for the 'real' theme
/// without regard to what jazzy did, and then here just map through brute force to the jazzy structure.
extension Theme {

    func jazzyGlobalData(from inDict: MustacheDict) -> MustacheDict {
        // copyright
        // jazzy_version
        // language_stub
        // module_version
        // docs_title
        // enable_katex
        inDict
    }

    func jazzyPageData(from inDict: MustacheDict) -> MustacheDict {
        // toc -> structure
        // split path for guide/not
        inDict
    }
}
