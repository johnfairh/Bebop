//
//  GatherOpts.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
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
    let mergeModulesOpt = BoolOpt(l: "merge-modules")

    let rootPassOpts = GatherJobOpts()
    private(set) var customModules = [GatherCustomModule]()

    private let published: Published

    // Top-level aliases for jazzy compatibility
    let xcodeBuildArgsAlias: AliasOpt
    let swiftBuildToolAlias: AliasOpt
    let objcJazzyAlias: AliasOpt
    let umbrellaHeaderAlias: AliasOpt
    let frameworkRootAlias: AliasOpt
    let moduleAlias: AliasOpt
    let sourcekittenSourceFileAlias: AliasOpt
    let githubURLAlias: AliasOpt
    let githubFilePrefixAlias: AliasOpt

    init(config: Config) {
        xcodeBuildArgsAlias = AliasOpt(realOpt: rootPassOpts.buildToolArgsOpt, s: "x", l: "xcodebuild-arguments")
        swiftBuildToolAlias = AliasOpt(realOpt: rootPassOpts.buildToolOpt, l: "swift-build-tool")
        objcJazzyAlias = AliasOpt(realOpt: rootPassOpts.objcDirectOpt, l: "objc")
        umbrellaHeaderAlias = AliasOpt(realOpt: rootPassOpts.objcHeaderFileOpt, l: "umbrella-header")
        frameworkRootAlias = AliasOpt(realOpt: rootPassOpts.objcIncludePathsOpt, l: "framework-root")
        sourcekittenSourceFileAlias = AliasOpt(realOpt: rootPassOpts.sourcekittenJSONFilesOpt, l: "sourcekitten-sourcefile")
        moduleAlias = AliasOpt(realOpt: moduleNamesOpt, l: "module")
        githubURLAlias = AliasOpt(realOpt: rootPassOpts.codeHostURLOpt, l: "github_url") // underscore intentional!
        githubFilePrefixAlias = AliasOpt(realOpt: rootPassOpts.codeHostFileURLOpt, l: "github-file-prefix")
        published = config.published

        config.register(rootPassOpts)
        config.registerSrcDirOpt(rootPassOpts.srcDirOpt)
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        // Check root pass options
        try rootPassOpts.checkOptions()
        try rootPassOpts.checkCascadedOptions()
        publish.setRootCodeHostURL(url: rootPassOpts.codeHostURLOpt.value)

        // Check our own options
        if customModulesOpts.configured {
            if moduleNamesOpt.configured {
                throw BBError(.errModulesOverlap)
            }
            if rootPassOpts.sourcekittenJSONFilesOpt.configured {
                throw BBError(.errCfgSknCustomModules)
            }
            try processCustomModules()
        }

        if moduleNamesOpt.configured {
            if let dupModule = moduleNamesOpt.value.firstDuplicate {
                throw BBError(.errRepeatedModule, dupModule)
            }
        }

        if rootPassOpts.sourcekittenJSONFilesOpt.configured {
            if moduleNamesOpt.value.count > 1 {
                throw BBError(.errCfgSknMultiModules)
            }
            if moduleNamesOpt.value.count == 0 {
                logWarning(.wrnSknModuleName)
                moduleNamesOpt.set(string: "Module")
            }
        }

        if !customModulesOpts.configured &&
            rootPassOpts.objcHeaderFileOpt.configured &&
            rootPassOpts.objcDirectOpt.configured &&
            !moduleNamesOpt.configured {
            logWarning(.wrnObjcModule)
            moduleNamesOpt.set(string: "Module")
        }

        if let buildTool = rootPassOpts.buildToolOpt.value,
            buildTool == .swift_symbolgraph,
            !customModulesOpts.configured && !moduleNamesOpt.configured {
            throw BBError(.errCfgSsgeModule)
        }

        if rootPassOpts.podspecOpt.configured &&
            (customModulesOpts.configured || moduleNamesOpt.value.count > 1) {
            throw BBError(.errCfgPodspecOuter)
        }
    }

    /// Publish module names & grouping policies.  This is a bit contorted:
    /// - if we used --modules then we've just discovered the names, and have a global option
    /// - if we used custom_modules then we can ignore what we've discovered and use the
    ///   configured list and individual module policies.
    func modulesToPublish(from passes: [String:GatherModulePass]) -> [PublishedModule] {
        if customModules.isEmpty {
            let groupPolicy = ModuleGroupPolicy(merge: mergeModulesOpt.value)
            return passes.map {
                PublishedModule(name: $0.key,
                                groupPolicy: groupPolicy,
                                pass: $0.value,
                                opts: rootPassOpts)
            }
        }
        return customModules.compactMap { mod in
            passes[mod.name].flatMap {
                PublishedModule(name: mod.name,
                                groupPolicy: mod.groupPolicy,
                                pass: $0,
                                opts: mod.moduleOpts)
            }
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

        let rootOpts = GatherCustomModule.RootOpts(jobOpts: rootPassOpts, mergeModulesOpt: mergeModulesOpt)
        try customModules.forEach {
            try $0.cascadeOptions(from: rootOpts)
        }
        logDebug("Gather: Finished custom_modules: \(customModules)")
    }

    /// Collect up and return all the jobs
    var jobs: [GatherJob] {
        if customModulesOpts.configured {
            return customModules.flatMap { $0.jobs }
        }
        if moduleNamesOpt.configured {
            return moduleNamesOpt.value.compactMap { moduleName in
                rootPassOpts.makeJob(moduleName: moduleName)
            }
        }
        return [rootPassOpts.makeJob(moduleName: nil)].compactMap { $0 }
    }
}

/// Helper to create a published module info entry from the various sources.
extension PublishedModule {
    init(name: String,
         groupPolicy: ModuleGroupPolicy,
         pass: GatherModulePass,
         opts: GatherJobOpts) {
        self.name = name
        self.version = pass.version
        self.groupPolicy = groupPolicy
        self.sourceDirectory = opts.effectiveSrcDir
        self.codeHostURL = opts.codeHostURLOpt.value
        // Manual setting overrides any discovered (podspec) URL
        self.codeHostFilePrefix =
            opts.codeHostFileURLOpt.value ?? pass.codeHostFileURL
    }
}

/// A custom module from the custom_modules YAML.
///
/// Either a job in itself, or a wrapper of 'passes'.
struct GatherCustomModule: CustomStringConvertible {
    let moduleNameOpt = StringOpt(y: "module")
    var name: String { moduleNameOpt.value! }
    let mergeModuleOpt = BoolOpt(y: "merge_module")
    let mergeModuleGroupOpt = LocStringOpt(y: "merge_module_group")
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
            throw BBError(.errMissingModule)
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

    struct RootOpts {
        let jobOpts: GatherJobOpts
        let mergeModulesOpt: BoolOpt
    }

    /// Cascade options down the tree.
    func cascadeOptions(from rootOpts: RootOpts) throws {
        // Cascade from root level to the module settings
        try moduleOpts.cascade(from: rootOpts.jobOpts)
        try moduleOpts.checkCascadedOptions()

        if rootOpts.mergeModulesOpt.configured && mergeModuleOpt.configured {
            throw BBError(.errCfgDupModMerge)
        }
        mergeModuleOpt.cascade(from: rootOpts.mergeModulesOpt)
        if !mergeModuleOpt.value && mergeModuleGroupOpt.configured {
            throw BBError(.errCfgBadModMerge, name)
        }

        // Cascade from module settings down to each pass
        try passes.forEach { pass in
            try pass.cascade(from: moduleOpts)
            try pass.checkCascadedOptions()
            try pass.checkPassOptions()
        }
    }

    var groupPolicy: ModuleGroupPolicy {
        ModuleGroupPolicy(merge: mergeModuleOpt.value, name: mergeModuleGroupOpt.value)
    }

    /// Generate jobs
    var jobs: [GatherJob] {
        guard let moduleName = moduleNameOpt.value else {
            preconditionFailure()
        }
        if passes.isEmpty {
            return moduleOpts.makeJob(moduleName: moduleName).flatMap { [$0] } ?? []
        }
        return passes.enumerated().compactMap { index, opts in
            opts.makeJob(moduleName: moduleName, passIndex: index)
        }
    }

    var description: String {
        "CustomModule {\(moduleNameOpt) \(moduleOpts) \(passes)}"
    }
}
