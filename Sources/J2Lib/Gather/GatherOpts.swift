//
//  GatherOpts.swift
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

    let rootPassOpts = GatherJobOpts()

    // Top-level aliases for jazzy compatibility
    let xcodeBuildArgsAlias: AliasOpt
    let swiftBuildToolAlias: AliasOpt
    let objcJazzyAlias: AliasOpt
    let umbrellaHeaderAlias: AliasOpt
    let frameworkRootAlias: AliasOpt
    let sdkAlias: AliasOpt

    init(config: Config) {
        xcodeBuildArgsAlias = AliasOpt(realOpt: rootPassOpts.buildToolArgsOpt, s: "x", l: "xcodebuild-arguments")
        swiftBuildToolAlias = AliasOpt(realOpt: rootPassOpts.buildToolOpt, l: "swift-build-tool")
        objcJazzyAlias = AliasOpt(realOpt: rootPassOpts.objcDirectOpt, l: "objc")
        umbrellaHeaderAlias = AliasOpt(realOpt: rootPassOpts.objcHeaderFileOpt, l: "umbrella-header")
        frameworkRootAlias = AliasOpt(realOpt: rootPassOpts.objcIncludePathsOpt, l: "framework-root")
        sdkAlias = AliasOpt(realOpt: rootPassOpts.objcSdkOpt, l: "sdk")

        config.register(rootPassOpts)
        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        // Check root pass options
        try rootPassOpts.checkOptions(published: published)
        try rootPassOpts.checkCascadedOptions()

        // Publish things we're obliged to
        if let srcDirURL = rootPassOpts.srcDirOpt.value {
            published.sourceDirectoryURL = srcDirURL
        }

        if rootPassOpts.objcDirectOpt.configured {
            published.defaultLanguage = .objc
        }

        // Check our own options
        if rootPassOpts.objcHeaderFileOpt.configured &&
            rootPassOpts.objcDirectOpt.configured &&
            !moduleNameOpt.configured {
            logWarning(.localized(.wrnObjcModule))
            moduleNameOpt.set(string: "Module")
        }
    }

    /// Collect up and return all the jobs
    var jobs: [GatherJob] {
        rootPassOpts.makeJobs(moduleName: moduleNameOpt.value)
    }
}
