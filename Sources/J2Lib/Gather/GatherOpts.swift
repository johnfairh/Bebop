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
    let srcDirOpt = PathOpt(l: "source-directory").help("DIRPATH")
    let buildToolOpt = EnumOpt<BuildTool>(l: "build-tool")
    let buildToolArgsOpt = StringListOpt(s: "b", l: "build-tool-arguments").help("ARG1,ARG2...")
    let availabilityDefaultsOpt = StringListOpt(l: "availability-defaults").help("AVAILABILITY1,AVAILABILITY2,...")
    let ignoreAvailabilityAttrOpt = BoolOpt(l: "ignore-availability-attr")

    let objcDirectOpt = BoolOpt(l: "objc-direct")
    let objcHeaderFileOpt = PathOpt(l: "objc-header-file").help("HEADERPATH")
    let objcIncludePathsOpt = PathListOpt(l: "objc-include-paths").help("INCLUDEDIRPATH1,INCLUDEDIRPATH2,...")
    let objcSdkOpt = EnumOpt<Sdk>(l: "objc-sdk").def(.macosx)

    enum Sdk: String, CaseIterable {
        case macosx
        case iphoneos
        case iphonesimulator
        case appletvos
        case appletvsimulator
        case watchos
        case watchsimulator
    }

    enum BuildTool: String, CaseIterable {
        case spm
        case xcodebuild
    }

    let xcodeBuildArgsAlias: AliasOpt
    let swiftBuildToolAlias: AliasOpt
    let objcJazzyAlias: AliasOpt
    let umbrellaHeaderAlias: AliasOpt
    let frameworkRootAlias: AliasOpt
    let sdkAlias: AliasOpt

    init(config: Config) {
        xcodeBuildArgsAlias = AliasOpt(realOpt: buildToolArgsOpt, s: "x", l: "xcodebuild-arguments")
        swiftBuildToolAlias = AliasOpt(realOpt: buildToolOpt, l: "swift-build-tool")
        objcJazzyAlias = AliasOpt(realOpt: objcDirectOpt, l: "objc")
        umbrellaHeaderAlias = AliasOpt(realOpt: objcHeaderFileOpt, l: "umbrella-header")
        frameworkRootAlias = AliasOpt(realOpt: objcIncludePathsOpt, l: "framework-root")
        sdkAlias = AliasOpt(realOpt: objcSdkOpt, l: "sdk")

        config.register(self)
    }

    func checkOptions(published: Config.Published) throws {
        try srcDirOpt.checkIsDirectory()
        if let srcDirURL = srcDirOpt.value {
            published.sourceDirectoryURL = srcDirURL
        }

        // Rigorously police the objc options...
        if objcDirectOpt.configured && buildToolOpt.configured {
            throw OptionsError(.localized(.errObjcBuildTools))
        }

        if (objcDirectOpt.configured || objcIncludePathsOpt.configured || objcSdkOpt.configured) &&
            !objcHeaderFileOpt.configured {
            throw OptionsError(.localized(.errObjcNoHeader))
        }

        if objcHeaderFileOpt.configured && !buildToolOpt.configured && !objcDirectOpt.configured {
            logDebug("Gather: ObjcHeaderFile and no BuildTool.  Inferring ObjcDirect")
            objcDirectOpt.set(bool: true)
        }

        if objcDirectOpt.configured {
            published.defaultLanguage = .objc
            #if !os(macOS)
            throw OptionsError(.localized(.errObjcLinux))
            #endif
        }

        if objcHeaderFileOpt.configured && buildToolOpt.configured {
            throw NotImplementedError("Objective-C with build-tool")
        }

        if objcHeaderFileOpt.configured && objcDirectOpt.configured && !moduleNameOpt.configured {
            logWarning(.localized(.wrnObjcModule))
            moduleNameOpt.set(string: "Module")
        }

        try objcHeaderFileOpt.checkIsFile()
        try objcIncludePathsOpt.checkAreDirectories()
    }

    var jobs: [GatherJob] {
        let availabilityRules =
            GatherAvailabilityRules(defaults: availabilityDefaultsOpt.value,
                                    ignoreAttr: ignoreAvailabilityAttrOpt.value)

        var jobs = [GatherJob]()

        // CLI Job

        if objcHeaderFileOpt.configured {
            precondition(objcDirectOpt.configured)
            precondition(moduleNameOpt.configured)
            #if os(macOS)
            jobs.append(.objcDirect(moduleName: moduleNameOpt.value!,
                                    headerFile: objcHeaderFileOpt.value!,
                                    includePaths: objcIncludePathsOpt.value,
                                    sdk: objcSdkOpt.value!,
                                    buildToolArgs: buildToolArgsOpt.value,
                                    availabilityRules: availabilityRules))
            #endif
        } else {
            jobs.append(.swift(moduleName: moduleNameOpt.value,
                               srcDir: srcDirOpt.value,
                               buildTool: buildToolOpt.value,
                               buildToolArgs: buildToolArgsOpt.value,
                               availabilityRules: availabilityRules))
        }

        return jobs
    }
}


struct GatherAvailabilityRules: Equatable {
    let defaults: [String]
    let ignoreAttr: Bool

    init(defaults: [String] = [], ignoreAttr: Bool = false) {
        self.defaults = defaults
        self.ignoreAttr = ignoreAttr
    }
}
