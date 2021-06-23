//
//  GatherJobSymbolGraph.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

// MARK: Import from binary swiftmodule using Swift-SymbolGraph-Extract

// Always Args:
// -module-name <module>
// -minimum-access-level private
// -output-dir <tmpdir>
// -skip-synthesized-members
//
// Only if buildToolArgs does _not_ contain them:
// -sdk <sdkpath>
// -target <target>
// -F <searchPaths ?? pwd>
// -I <searchPaths ?? pwd>

extension GatherJob {
    /// Job to run `swift symbolgraph-extract` on some module and massage the created JSON
    /// into something approximating what SourceKit would create, so that we can feed into that codepath.
    struct SymbolGraph: Equatable {
        let moduleName: String
        let searchURLs: [URL]
        let buildToolArgs: [String]
        let sdk: Gather.Sdk
        let target: String
        let defOptions: Gather.DefOptions

        /// This layer's job is to manage the CLI args, invoke the program, figure out what it created,
        /// use `GatherSymbolGraph` to convert the data into `SourceKittenDict`s, and then convert
        /// that lot into `GatherDef`s.
        func execute() throws -> GatherModulePass {
            let tmpDir = try TemporaryDirectory()
            var args = [
                "-module-name", moduleName,
                "-minimum-access-level", "private",
                "-output-dir", tmpDir.directoryURL.path,
                "-skip-synthesized-members"
            ]
            let userArgs = buildToolArgs.joined(separator: " ")
            try ["-module", "-minimum-access-level", "-output-dir"].forEach { arg in
                if userArgs.contains(arg) {
                    throw BBError(.errCfgSsgeArgs, arg)
                }
            }

            #if os(macOS) // SDK can just be omitted on Linux
            if !userArgs.contains("-sdk ") {
                args += ["-sdk", try sdk.getPath()]
            }
            #endif

            if !userArgs.re_isMatch("-target ") {
                args += ["-target", target]
            }
            let searchPaths = searchURLs.isEmpty ?
                [FileManager.default.currentDirectory.path] :
                searchURLs.map { $0.path }

            if !userArgs.contains("-F ") {
                args += searchPaths.flatMap { ["-F", $0] }
            }
            if !userArgs.contains("-I ") {
                args += searchPaths.flatMap { ["-I", $0] }
            }
            logDebug("Calling swift-symbolgraph, args:")
            args.forEach { logDebug("  \($0)") }

            let results: Exec.Results
            if let injectedPath = ProcessInfo.processInfo.environment["BEBOP_SWIFT_SYMBOLGRAPH_EXTRACT"] {
                logDebug("Using injected swift-symbolgraph-extract path: \(injectedPath)")
                results = Exec.run(injectedPath, args, stderr: .merge)
            } else {
                results = Exec.run("/usr/bin/env", ["swift", "symbolgraph-extract"] + args, stderr: .merge)
            }
            if results.terminationStatus != 0 {
                throw BBError(.errCfgSsgeExec, results.failureReport)
            }

            let mainSymbolFileURL = tmpDir.directoryURL.appendingPathComponent("\(moduleName).symbols.json")
            guard let mainSymbolData = try? Data(contentsOf: mainSymbolFileURL) else {
                throw BBError(.errCfgSsgeMainMissing)
            }
            logDebug("Decoding main symbolgraph JSON for \(moduleName)")
            var dicts = [try GatherSymbolGraph.decode(data: mainSymbolData, extensionModuleName: moduleName)]

            // Extensions of things from other modules come in their own files, one per module.
            // Apple have put the foreign module in the filename and not the metadata...
            try tmpDir.directoryURL.filesMatching("*@*.symbols.json").forEach { url in
                guard let otherModuleName = url.lastPathComponent.re_match(#"@(.*?)\."#)?[1],
                    let otherSymbolData = try? Data(contentsOf: url) else {
                    logWarning(.wrnSsgeOddFilename, url.lastPathComponent)
                    return
                }
                logDebug("Decoding \(moduleName)'s extension symbolgraph JSON for \(otherModuleName)")
                try dicts.append(GatherSymbolGraph.decode(data: otherSymbolData,
                                                         extensionModuleName: otherModuleName))
            }

            logDebug("Gathering sourcekitten defs...")

            let defs = dicts.compactMap {
                GatherDef(sourceKittenDict: $0, defOptions: defOptions)
            }

            return GatherModulePass(moduleName: moduleName, files: defs.map { ("", $0) })
        }
    }
}
