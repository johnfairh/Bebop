//
//  GatherJobOpts.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

// when we have all the build options known, refactor all the mutex checks
// and cascade logic -- no point now as we keep adding/discovering things.

/// The common option set that can be set at outer, module, or module-pass level.
/// These are the options that fundamentally generate `GatherJob`s.
final class GatherJobOpts: Configurable {
    let srcDirOpt = PathOpt(l: "source-directory").help("DIRPATH")
    var effectiveSrcDir: URL { srcDirOpt.value ?? FileManager.default.currentDirectory }
    let buildToolOpt = EnumOpt<Gather.BuildTool>(l: "build-tool")
    let buildToolArgsOpt = StringListOpt(s: "b", l: "build-tool-arguments").help("ARG1,ARG2...")

    let availabilityDefaultsOpt = StringListOpt(l: "availability-defaults").help("AVAILABILITY1,AVAILABILITY2,...")
    let ignoreAvailabilityAttrOpt = BoolOpt(l: "ignore-availability-attr")

    let inheritedDocsStyleOpt = EnumOpt<Gather.InheritedDocsStyle>(l: "inherited-docs-style").def(.full)
    var inheritedDocsStyle: Gather.InheritedDocsStyle { inheritedDocsStyleOpt.value! }
    let inheritedDocsExtensionStyleOpt = EnumOpt<Gather.InheritedDocsStyle>(l: "inherited-docs-extension-style").def(.brief)
    var inheritedDocsExtensionStyle: Gather.InheritedDocsStyle { inheritedDocsExtensionStyleOpt.value! }

    let sourcekittenJSONFilesOpt = PathListOpt(s: "s", l: "sourcekitten-json-files").help("FILEPATH1,FILEPATH2,...")
    let bebopJSONFilesOpt = PathListOpt(l: "bebop-json-files").help("FILEPATH1,FILEPATH2,...")

    let objcDirectOpt = BoolOpt(l: "objc-direct")
    let objcHeaderFileOpt = PathOpt(l: "objc-header-file").help("FILEPATH")
    let objcIncludePathsOpt = PathListOpt(l: "objc-include-paths").help("DIRPATH1,DIRPATH2,...")
    let sdkOpt = EnumOpt<Gather.Sdk>(l: "sdk").def(.macosx)
    var sdk: Gather.Sdk { sdkOpt.value! }

    let symbolGraphTargetOpt = StringOpt(l: "symbolgraph-target").help("LLVMTARGET")
    var symbolGraphTarget: String { symbolGraphTargetOpt.value ?? hostTargetTriple }
    let symbolGraphSearchPathsOpt = PathListOpt(l: "symbolgraph-search-paths").help("DIRPATH1,DIRPATH2,...")

    let codeHostURLOpt = LocStringOpt(l: "code-host-url").help("CODEHOSTURL")
    let codeHostFileURLOpt = StringOpt(l: "code-host-file-url").help("CODEHOSTFILEURL")

    let podspecOpt = PathOpt(l: "podspec").help("PODSPECPATH")
    let podSourcesOpt = StringListOpt(l: "pod-sources").help("PODSOURCE,PODSOURCE,...")

    /// First pass of options-checking, that individual things entered are valid
    func checkOptions() throws {
        try checkBaseOptions()
    }

    func checkBaseOptions() throws {
        // don't check srcdir until we know if it's supposed to exist
        try objcHeaderFileOpt.checkIsFile()
        try objcIncludePathsOpt.checkAreDirectories()
        try sourcekittenJSONFilesOpt.checkAreFiles()
        try bebopJSONFilesOpt.checkAreFiles()
        try symbolGraphSearchPathsOpt.checkAreDirectories()
        try podspecOpt.checkIsFile()

        if let target = symbolGraphTargetOpt.value {
            let targetTriple = target.components(separatedBy: "-")
            if targetTriple.count < 3 { // "linux-gnu" sob
                throw BBError(.errCfgSsgeTriple, symbolGraphTarget)
            }
        }
    }

    /// Update configuration from a parent set that we're specializing
    func cascade(from: GatherJobOpts) throws {
        // srcdir: always cascade
        srcDirOpt.cascade(from: from.srcDirOpt)
        // buildtool: don't cascade if objcdirect/jsonfiles/podspec [mutually exclusive]
        //            don't cascade if objcheaderfile [not implemented]
        if !objcDirectOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !bebopJSONFilesOpt.configured &&
            !objcHeaderFileOpt.configured &&
            !podspecOpt.configured {
            buildToolOpt.cascade(from: from.buildToolOpt)
        }
        // buildtoolargs: always cascade
        buildToolArgsOpt.cascade(from: from.buildToolArgsOpt)
        // availability: always cascade
        availabilityDefaultsOpt.cascade(from: from.availabilityDefaultsOpt)
        ignoreAvailabilityAttrOpt.cascade(from: from.ignoreAvailabilityAttrOpt)
        // inheritdocs: always cascade
        inheritedDocsStyleOpt.cascade(from: from.inheritedDocsStyleOpt)
        inheritedDocsExtensionStyleOpt.cascade(from: from.inheritedDocsExtensionStyleOpt)
        // objcdirect: don't cascade if buildtool/jsonfiles/podspec [mutually exclusive]
        if !buildToolOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !bebopJSONFilesOpt.configured &&
            !podspecOpt.configured {
            objcDirectOpt.cascade(from: from.objcDirectOpt)
        }
        // objcheaderfile: don't cascade if build tool [not implemented]
        //                 don't cascade if jsonfiles/podspec [mutually exclusive]
        if !buildToolOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !bebopJSONFilesOpt.configured &&
            !podspecOpt.configured {
            objcHeaderFileOpt.cascade(from: from.objcHeaderFileOpt)
        }
        // objcincludepaths: always cascade
        objcIncludePathsOpt.cascade(from: from.objcIncludePathsOpt)
        // sdk: always cascade
        sdkOpt.cascade(from: from.sdkOpt)
        // sourcekittensourcefiles: never cascade
        // declsjsonfiles: cascade unless some built tool option set (mutually exclusive)
        if !buildToolOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !objcDirectOpt.configured &&
            !objcHeaderFileOpt.configured &&
            !podspecOpt.configured {
            bebopJSONFilesOpt.cascade(from: from.bebopJSONFilesOpt)
        }
        // symbolgraph-target, -searchpaths: always cascade, use driven by buildtool
        symbolGraphTargetOpt.cascade(from: from.symbolGraphTargetOpt)
        symbolGraphSearchPathsOpt.cascade(from: from.symbolGraphSearchPathsOpt)
        // codehost: cascade, no effect on build process
        codeHostURLOpt.cascade(from: from.codeHostURLOpt)
        codeHostFileURLOpt.cascade(from: from.codeHostFileURLOpt)
        // podspec: do not cascade
        // pod-sources: always cascade
        podSourcesOpt.cascade(from: from.podSourcesOpt)
    }

    /// Second pass of options-checking, of inter-option consistency after parent cascade
    func checkCascadedOptions() throws {
        // Rigorously police the objc options...
        if objcDirectOpt.configured && buildToolOpt.configured {
            throw BBError(.errObjcBuildTools)
        }

        if (objcDirectOpt.configured || objcIncludePathsOpt.configured) &&
            !objcHeaderFileOpt.configured {
            throw BBError(.errObjcNoHeader)
        }

        if sourcekittenJSONFilesOpt.configured &&
            (buildToolOpt.configured || objcDirectOpt.configured || objcHeaderFileOpt.configured) {
            throw BBError(.errCfgSknBuildTool)
        }

        if bebopJSONFilesOpt.configured &&
            (sourcekittenJSONFilesOpt.configured || buildToolOpt.configured || objcDirectOpt.configured || objcHeaderFileOpt.configured) {
            throw BBError(.errCfgBebopJsonMutex)
        }

        if podspecOpt.configured &&
            (sourcekittenJSONFilesOpt.configured || buildToolOpt.configured || objcDirectOpt.configured ||
                objcHeaderFileOpt.configured || bebopJSONFilesOpt.configured) {
            throw BBError(.errCfgPodspecBuild)
        }

        if objcHeaderFileOpt.configured && !objcDirectOpt.configured &&
            !buildToolOpt.configured && !sourcekittenJSONFilesOpt.configured {
            logDebug("Gather: ObjcHeaderFile, no BuildTool, no srcfile.  Inferring ObjcDirect")
            objcDirectOpt.set(bool: true)
        }

        if objcDirectOpt.configured {
            #if !os(macOS)
            throw BBError(.errObjcLinux)
            #endif
        }

        if objcHeaderFileOpt.configured && buildToolOpt.configured {
            throw BBError(.errNotImplemented, "Objective-C with build-tool")
        }

        // SrcDir -- used for calculating relative code-host links *and* for swift
        // source builds to locate the actual sources.  Only needs to be a real directory
        // in the second case.
        if !objcHeaderFileOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !bebopJSONFilesOpt.configured &&
            buildToolOpt.value != .some(.swift_symbolgraph) {
            try srcDirOpt.checkIsDirectory()
        }
    }

    /// Third pass of options-checking -- called just for passes, not top-level or modules.
    func checkPassOptions() throws {
        if podspecOpt.configured {
            throw BBError(.errCfgPodspecPass)
        }
    }

    /// Generate a job from the options
    func makeJob(moduleName: String?, passIndex: Int? = nil) -> GatherJob? {
        let defOptions = Gather.DefOptions(availability:
                                            Gather.Availability(defaults: availabilityDefaultsOpt.value,
                                                                ignoreAttr: ignoreAvailabilityAttrOpt.value),
                                           inheritedDocs: inheritedDocsStyle,
                                           inheritedExtensionDocs: inheritedDocsExtensionStyle)

        let passStr = passIndex.flatMap { " pass \($0)" } ?? ""

        if let objcHeaderFile = objcHeaderFileOpt.value {
            precondition(objcDirectOpt.configured)
            precondition(moduleName != nil)
            #if os(macOS)
            return GatherJob(objcTitle: "Objective-C module \(moduleName!)\(passStr)",
                             moduleName: moduleName!,
                             headerFile: objcHeaderFile,
                             includePaths: objcIncludePathsOpt.value,
                             sdk: sdk,
                             buildToolArgs: buildToolArgsOpt.value,
                             defOptions: defOptions)
            #else
            return nil
            #endif
        } else if sourcekittenJSONFilesOpt.configured {
            precondition(moduleName != nil)
            return GatherJob(sknImportTitle: "SourceKitten import module \(moduleName!)\(passStr)",
                             moduleName: moduleName!,
                             fileURLs: sourcekittenJSONFilesOpt.value,
                             defOptions: defOptions)
        } else if bebopJSONFilesOpt.configured {
            return GatherJob(importTitle: "JSON import module \(moduleName ?? "(all)")\(passStr)",
                             moduleName: moduleName,
                             passIndex: passIndex,
                             fileURLs: bebopJSONFilesOpt.value)
        } else if let buildTool = buildToolOpt.value, buildTool == .swift_symbolgraph {
            // Swift from .swiftmodule
            return GatherJob(symbolgraphTitle: "Swift module (symbolgraph) \(moduleName!)\(passStr)",
                             moduleName: moduleName!,
                             searchURLs: symbolGraphSearchPathsOpt.value,
                             buildToolArgs: buildToolArgsOpt.value,
                             sdk: sdk,
                             target: symbolGraphTarget,
                             defOptions: defOptions)
        } else if let podspecURL = podspecOpt.value  {
            // Swift from podspec
            return GatherJob(podspecTitle: "Podspec \(moduleName ?? "(default)")\(passStr)",
                             moduleName: moduleName,
                             podspecURL: podspecURL,
                             podSources: podSourcesOpt.value,
                             defOptions: defOptions)
        }

        // Default: Swift from source
        return GatherJob(swiftTitle: "Swift module \(moduleName ?? "(default)")\(passStr)",
                         moduleName: moduleName,
                         srcDir: srcDirOpt.value,
                         buildTool: buildToolOpt.value,
                         buildToolArgs: buildToolArgsOpt.value,
                         defOptions: defOptions)
    }

    lazy var hostTargetTriple: String = {
        guard let swiftVersionOutput = Exec.run("/usr/bin/env", "swift", "-version").successString,
            let target = swiftVersionOutput.re_match("Target: (.*)$")?[1] else {
                let defaultTarget = "x86_64-apple-macosx10.15"
                logWarning(.wrnSsgeTriple, defaultTarget)
                return defaultTarget
        }
        logDebug("Using host target from `swift -version`: \(target)")
        return target
    }()
}

// MARK: Useful types

extension Gather {
    /// SDK for Objective-C building
    enum Sdk: String, CaseIterable {
        case macosx
        case iphoneos
        case iphonesimulator
        case appletvos
        case appletvsimulator
        case watchos
        case watchsimulator

        func getPath() throws -> String {
            let sdkPathResults = Exec.run("/usr/bin/env", "xcrun", "--show-sdk-path", "--sdk", rawValue, stderr: .merge)
            guard let sdkPath = sdkPathResults.successString else {
                throw BBError(.errSdk, sdkPathResults.failureReport)
            }
            return sdkPath
        }
    }

    /// Build tool for Swift/etc building
    enum BuildTool: String, CaseIterable {
        case spm
        case xcodebuild
        case swift_symbolgraph
    }

    /// Collected availability options
    struct Availability: Equatable {
        let defaults: [String]
        let ignoreAttr: Bool

        init(defaults: [String] = [], ignoreAttr: Bool = false) {
            self.defaults = defaults
            self.ignoreAttr = ignoreAttr
        }
    }

    /// How to handle inherited docs for a declaration
    enum InheritedDocsStyle: String, CaseIterable {
        case none
        case brief
        case full
    }

    /// Collected options that affect def building
    struct DefOptions: Equatable {
        let availability: Availability
        let inheritedDocsStyle: InheritedDocsStyle
        let inheritedExtensionDocsStyle: InheritedDocsStyle

        init(availability: Availability = .init(),
             inheritedDocs: InheritedDocsStyle = .full,
             inheritedExtensionDocs: InheritedDocsStyle = .brief) {
            self.availability = availability
            self.inheritedDocsStyle = inheritedDocs
            self.inheritedExtensionDocsStyle = inheritedExtensionDocs
        }
    }
}
