//
//  GatherConfig.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Type  responsible for declaring and parsing the config options.
///
/// Its output is a set of `GatherJob`s that are self-contained recipes on how to
/// create a `GatherModulePass`.
///
/// The main interesting piece here is dealing with `modules`.
struct GatherOpts : Configurable {
    let moduleNameOpt = StringOpt(s: "m", l: "module").help("MODULE_NAME")
    let srcDirOpt = PathOpt(l: "source-directory").help("DIRPATH")
    let buildToolOpt = EnumOpt<GatherBuildTool>(l: "build-tool")
    let buildToolArgsOpt = StringListOpt(s: "b", l: "build-tool-arguments").help("ARG1,ARG2...")
    let xcodeBuildArgsAlias: AliasOpt
    let swiftBuildToolAlias: AliasOpt

    init(config: Config) {
        xcodeBuildArgsAlias = AliasOpt(realOpt: buildToolArgsOpt, s: "x", l: "xcodebuild-arguments")
        swiftBuildToolAlias = AliasOpt(realOpt: buildToolOpt, l: "swift-build-tool")

        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        try srcDirOpt.checkIsDirectory()
        if let srcDirURL = srcDirOpt.value {
            published.sourceDirectoryURL = srcDirURL
        }
    }

    var jobs: [GatherJob] {
        return [.swift(moduleName: moduleNameOpt.value,
                       srcDir: srcDirOpt.value,
                       buildTool: buildToolOpt.value,
                       buildToolArgs: buildToolArgsOpt.value)]
    }
}

enum GatherBuildTool: String, CaseIterable {
    case spm
    case xcodebuild
}
