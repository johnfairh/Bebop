//
//  GatherOpts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Yams
import Foundation

/// Type  responsible for declaring and parsing the config options.
///
/// Its output is a set of `GatherJob`s that are self-contained recipes on how to
/// create a `GatherModulePass`.
///
/// The main interesting piece here is dealing with `modules`.
final class GatherOpts : Configurable {
    let moduleNamesOpt = StringListOpt(s: "m", l: "modules").help("MODULE_NAME,...")
    let customModulesOpts = YamlOpt(y: "custom_modules")

    let rootPassOpts = GatherJobOpts()
    private(set) var customModules = [GatherCustomModule]()

    private let published: Config.Published

    // Top-level aliases for jazzy compatibility
    let xcodeBuildArgsAlias: AliasOpt
    let swiftBuildToolAlias: AliasOpt
    let objcJazzyAlias: AliasOpt
    let umbrellaHeaderAlias: AliasOpt
    let frameworkRootAlias: AliasOpt
    let sdkAlias: AliasOpt
    let moduleAlias: AliasOpt

    init(config: Config) {
        xcodeBuildArgsAlias = AliasOpt(realOpt: rootPassOpts.buildToolArgsOpt, s: "x", l: "xcodebuild-arguments")
        swiftBuildToolAlias = AliasOpt(realOpt: rootPassOpts.buildToolOpt, l: "swift-build-tool")
        objcJazzyAlias = AliasOpt(realOpt: rootPassOpts.objcDirectOpt, l: "objc")
        umbrellaHeaderAlias = AliasOpt(realOpt: rootPassOpts.objcHeaderFileOpt, l: "umbrella-header")
        frameworkRootAlias = AliasOpt(realOpt: rootPassOpts.objcIncludePathsOpt, l: "framework-root")
        sdkAlias = AliasOpt(realOpt: rootPassOpts.objcSdkOpt, l: "sdk")
        moduleAlias = AliasOpt(realOpt: moduleNamesOpt, l: "module")
        published = config.published

        config.register(rootPassOpts)
        config.registerSrcDirOpt(rootPassOpts.srcDirOpt)
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
        if customModulesOpts.configured {
            if moduleNamesOpt.configured {
                throw OptionsError(.localized(.errModulesOverlap))
            }
            try processCustomModules()
        }

        if moduleNamesOpt.configured {
            if let dupModule = moduleNamesOpt.value.firstDuplicate {
                throw OptionsError(.localized(.errRepeatedModule, dupModule))
            }
        }

        if !customModulesOpts.configured &&
            rootPassOpts.objcHeaderFileOpt.configured &&
            rootPassOpts.objcDirectOpt.configured &&
            !moduleNamesOpt.configured {
            logWarning(.localized(.wrnObjcModule))
            moduleNamesOpt.set(string: "Module")
        }
    }

    func processCustomModules() throws {
        logDebug("Gather: Parsing custom_modules")
        let modulesSequence = try customModulesOpts.value!.checkSequence(context: "custom_modules")
        customModules = try modulesSequence.map { customModule in
            let moduleMapping = try customModule.checkMapping(context: "custom_modules[]")
            return try GatherCustomModule(yamlMapping: moduleMapping,
                                          relativePathBaseURL: published.configRelativePathBaseURL)
        }

        try customModules.forEach {
            try $0.cascadeOptions(from: rootPassOpts)
        }
        logDebug("Gather: Finished custom_modules: \(customModules)")
    }

    /// Collect up and return all the jobs
    var jobs: [GatherJob] {
        if customModulesOpts.configured {
            return customModules.flatMap { $0.jobs }
        }
        if moduleNamesOpt.configured {
            return moduleNamesOpt.value.flatMap { moduleName in
                rootPassOpts.makeJobs(moduleName: moduleName)
            }
        }
        return rootPassOpts.makeJobs(moduleName: nil)
    }
}

/// A custom module from the custom_modules YAML.
///
/// Either a job in itself, or a wrapper of 'passes'.
struct GatherCustomModule: CustomStringConvertible {
    let moduleNameOpt = StringOpt(y: "module")
    let passesOpt = YamlOpt(y: "passes")
    let moduleOpts = GatherJobOpts()
    private(set) var passes: [GatherJobOpts] = []

    /// Set up a custom module & passes from some YAML
    init(yamlMapping: Node.Mapping, relativePathBaseURL: URL?) throws {
        let parser = OptsParser(relativePathBase: relativePathBaseURL)
        parser.addOpts(from: self)
        parser.addOpts(from: moduleOpts)
        try parser.apply(mapping: yamlMapping)

        if !moduleNameOpt.configured {
            throw OptionsError(.localized(.errMissingModule))
        }
        try moduleOpts.checkBaseOptions()

        if passesOpt.configured {
            let passesSequence = try passesOpt.value!.checkSequence(context: "custom_modules[].passes")
            passes = try passesSequence.map { customPass in
                let passMapping = try customPass.checkMapping(context: "custom_modules[].passes[]")
                let passOpts = GatherJobOpts()
                let parser = OptsParser(relativePathBase: relativePathBaseURL)
                parser.addOpts(from: passOpts)
                try parser.apply(mapping: passMapping)
                try passOpts.checkBaseOptions()
                return passOpts
            }
        }
    }

    /// Cascade options down the tree.
    func cascadeOptions(from: GatherJobOpts) throws {
        // Cascade from root level to the module settings
        try moduleOpts.cascade(from: from)
        try moduleOpts.checkCascadedOptions()

        // Cascade from module settings down to each pass
        try passes.forEach { pass in
            try pass.cascade(from: moduleOpts)
            try pass.checkCascadedOptions()
        }
    }

    /// Generate jobs
    var jobs: [GatherJob] {
        guard let moduleName = moduleNameOpt.value else {
            preconditionFailure()
        }
        if passes.isEmpty {
            return moduleOpts.makeJobs(moduleName: moduleName)
        }
        return passes.flatMap { $0.makeJobs(moduleName: moduleName) }
    }

    var description: String {
        "CustomModule {\(moduleNameOpt) \(moduleOpts) \(passes)}"
    }
}
