//
//  GatherJobOpts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// when we have all the build options known, refactor all the mutex checks
// and cascade logic -- no point now as we keep adding/discovering things.

/// The common option set that can be set at outer, module, or module-pass level.
/// These are the options that fundamentally generate `GatherJob`s.
final class GatherJobOpts: Configurable, CustomStringConvertible {
    let srcDirOpt = PathOpt(l: "source-directory").help("DIRPATH")
    let buildToolOpt = EnumOpt<Gather.BuildTool>(l: "build-tool")
    let buildToolArgsOpt = StringListOpt(s: "b", l: "build-tool-arguments").help("ARG1,ARG2...")

    let availabilityDefaultsOpt = StringListOpt(l: "availability-defaults").help("AVAILABILITY1,AVAILABILITY2,...")
    let ignoreAvailabilityAttrOpt = BoolOpt(l: "ignore-availability-attr")

    let sourcekittenJSONFilesOpt = PathListOpt(s: "s", l: "sourcekitten-json-files").help("FILEPATH1,FILEPATH2,...")
    let j2JSONFilesOpt = PathListOpt(l: "j2-json-files").help("FILEPATH1,FILEPATH2,...")

    let objcDirectOpt = BoolOpt(l: "objc-direct")
    let objcHeaderFileOpt = PathOpt(l: "objc-header-file").help("FILEPATH")
    let objcIncludePathsOpt = PathListOpt(l: "objc-include-paths").help("DIRPATH1,DIRPATH2,...")
    let sdkOpt = EnumOpt<Gather.Sdk>(l: "sdk").def(.macosx)
    var sdk: Gather.Sdk { sdkOpt.value! }

    let swiftSymbolGraphTargetOpt = StringOpt(l: "swift-symbolgraph-target").def("x86_64-apple-macosx10.15")
    var swiftSymbolGraphTarget: String { swiftSymbolGraphTargetOpt.value! }

    var description: String {
        "GatherJobOpts {\(srcDirOpt) \(buildToolOpt) \(buildToolArgsOpt) \(availabilityDefaultsOpt) \(ignoreAvailabilityAttrOpt) \(objcDirectOpt) " +
        "\(objcHeaderFileOpt) \(objcIncludePathsOpt) \(sdkOpt)} \(sourcekittenJSONFilesOpt) \(j2JSONFilesOpt) " +
        "\(swiftSymbolGraphTargetOpt)} "
    }

    /// First pass of options-checking, that individual things entered are valid
    func checkOptions(published: Config.Published) throws {
        try checkBaseOptions()
    }

    func checkBaseOptions() throws {
        try srcDirOpt.checkIsDirectory()
        try objcHeaderFileOpt.checkIsFile()
        try objcIncludePathsOpt.checkAreDirectories()
        try sourcekittenJSONFilesOpt.checkAreFiles()
        try j2JSONFilesOpt.checkAreFiles()

        let targetTriple = swiftSymbolGraphTarget.components(separatedBy: "-")
        if targetTriple.count != 3 {
            throw OptionsError(.localized(.errCfgSsgeTriple, swiftSymbolGraphTarget))
        }
    }

    /// Update configuration from a parent set that we're specializing
    func cascade(from: GatherJobOpts) throws {
        // srcdir: always cascade
        srcDirOpt.cascade(from: from.srcDirOpt)
        // buildtool: don't cascade if objcdirect/jsonfiles [mutually exclusive]
        //            don't cascade if objcheaderfile [not implemented]
        if !objcDirectOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !j2JSONFilesOpt.configured &&
            !objcHeaderFileOpt.configured {
            buildToolOpt.cascade(from: from.buildToolOpt)
        }
        // buildtoolargs: always cascade
        buildToolArgsOpt.cascade(from: from.buildToolArgsOpt)
        // availability: always cascade
        availabilityDefaultsOpt.cascade(from: from.availabilityDefaultsOpt)
        ignoreAvailabilityAttrOpt.cascade(from: from.ignoreAvailabilityAttrOpt)
        // objcdirect: don't cascade if buildtool/jsonfiles [mutually exclusive]
        if !buildToolOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !j2JSONFilesOpt.configured {
            objcDirectOpt.cascade(from: from.objcDirectOpt)
        }
        // objcheaderfile: don't cascade if build tool [not implemented]
        //                 don't cascade if jsonfiles [mutually exclusive]
        if !buildToolOpt.configured &&
            !sourcekittenJSONFilesOpt.configured &&
            !j2JSONFilesOpt.configured {
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
            !objcHeaderFileOpt.configured {
            j2JSONFilesOpt.cascade(from: from.j2JSONFilesOpt)
        }
        // swift-symbolgraph-target: always cascade, use driven by buildtool
        swiftSymbolGraphTargetOpt.cascade(from: from.swiftSymbolGraphTargetOpt)
    }

    /// Second pass of options-checking, of inter-option consistency after parent cascade
    func checkCascadedOptions() throws {
        // Rigorously police the objc options...
        if objcDirectOpt.configured && buildToolOpt.configured {
            throw OptionsError(.localized(.errObjcBuildTools))
        }

        if (objcDirectOpt.configured || objcIncludePathsOpt.configured) &&
            !objcHeaderFileOpt.configured {
            throw OptionsError(.localized(.errObjcNoHeader))
        }

        if sourcekittenJSONFilesOpt.configured &&
            (buildToolOpt.configured || objcDirectOpt.configured || objcHeaderFileOpt.configured) {
            throw OptionsError(.localized(.errCfgSknBuildTool))
        }

        if j2JSONFilesOpt.configured &&
            (sourcekittenJSONFilesOpt.configured || buildToolOpt.configured || objcDirectOpt.configured || objcHeaderFileOpt.configured) {
            throw OptionsError(.localized(.errCfgJ2jsonMutex))
        }

        if objcHeaderFileOpt.configured && !objcDirectOpt.configured &&
            !buildToolOpt.configured && !sourcekittenJSONFilesOpt.configured {
            logDebug("Gather: ObjcHeaderFile, no BuildTool, no srcfile.  Inferring ObjcDirect")
            objcDirectOpt.set(bool: true)
        }

        if objcDirectOpt.configured {
            #if !os(macOS)
            throw OptionsError(.localized(.errObjcLinux))
            #endif
        }

        if objcHeaderFileOpt.configured && buildToolOpt.configured {
            throw NotImplementedError("Objective-C with build-tool")
        }
    }

    /// Generate jobs from the options
    func makeJobs(moduleName: String?, passIndex: Int? = nil) -> [GatherJob] {
        let availability =
            Gather.Availability(defaults: availabilityDefaultsOpt.value,
                                ignoreAttr: ignoreAvailabilityAttrOpt.value)

        var jobs = [GatherJob]()

        let passStr = passIndex.flatMap { " pass \($0)" } ?? ""

        if let objcHeaderFile = objcHeaderFileOpt.value {
            precondition(objcDirectOpt.configured)
            precondition(moduleName != nil)
            #if os(macOS)
            jobs.append(GatherJob(objcTitle: "Objective-C module \(moduleName!)\(passStr)",
                                  moduleName: moduleName!,
                                  headerFile: objcHeaderFile,
                                  includePaths: objcIncludePathsOpt.value,
                                  sdk: sdk,
                                  buildToolArgs: buildToolArgsOpt.value,
                                  availability: availability))
            #endif
        } else if sourcekittenJSONFilesOpt.configured {
            precondition(moduleName != nil)
            jobs.append(GatherJob(sknImportTitle: "SourceKitten import module \(moduleName!)\(passStr)",
                                  moduleName: moduleName!,
                                  fileURLs: sourcekittenJSONFilesOpt.value,
                                  availability: availability))
        } else if j2JSONFilesOpt.configured {
            jobs.append(GatherJob(importTitle: "JSON import module \(moduleName ?? "(all)")\(passStr)",
                                  moduleName: moduleName,
                                  passIndex: passIndex,
                                  fileURLs: j2JSONFilesOpt.value))
        } else if let buildTool = buildToolOpt.value, buildTool == .swift_symbolgraph {
            // Swift from .swiftmodule
            jobs.append(GatherJob(symbolgraphTitle: "Swift module (symbolgraph) \(moduleName!)\(passStr)",
                moduleName: moduleName!,
                srcDir: srcDirOpt.value,
                buildToolArgs: buildToolArgsOpt.value,
                sdk: sdk,
                target: swiftSymbolGraphTarget,
                availability: availability))
        } else {
            // Swift from source
            jobs.append(GatherJob(swiftTitle: "Swift module \(moduleName ?? "(default)")\(passStr)",
                                  moduleName: moduleName,
                                  srcDir: srcDirOpt.value,
                                  buildTool: buildToolOpt.value,
                                  buildToolArgs: buildToolArgsOpt.value,
                                  availability: availability))
        }

        return jobs
    }
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
                throw GatherError(.localized(.errSdk) + "\n\(sdkPathResults.failureReport)")
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
}
