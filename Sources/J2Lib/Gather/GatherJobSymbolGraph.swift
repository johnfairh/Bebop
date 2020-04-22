//
//  GatherJobSymbolGraph.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Import from binary swiftmodule using Swift-SymbolGraph-Extract

// Always Args:
// --module-name=<module>
// --minimum-access-level=private
// --output-dir=<tmpdir>
//
// If buildToolArgs.empty:
// --sdk=<sdkpath>
// --target=<target>
// --skip-synthesized-members
// -F=<searchPaths ?? pwd>
// -I=<searchPaths ?? pwd>

extension GatherJob {
    /// Job to run `swift symbolgraph-extract` on some module and massage the created JSON
    /// into something approximating what SourceKit would create, so that we can feed into that codepath.
    struct SymbolGraph: Equatable {
        let moduleName: String
        let searchURLs: [URL]
        let buildToolArgs: [String]
        let sdk: Gather.Sdk
        let target: String
        let availability: Gather.Availability

        /// This layer's job is to manage the CLI args, invoke the program, figure out what it created,
        /// use `GatherSymbolGraph` to convert the data into `SourceKittenDict`s, and then convert
        /// that lot into `GatherDef`s.
        func execute() throws -> GatherModulePass {
            let tmpDir = try TemporaryDirectory()
            var args = [
                "--module-name=\(moduleName)",
                "--minimum-access-level=private",
                "--output-dir=\(tmpDir.directoryURL.path)"
            ]
            if buildToolArgs.isEmpty {
                args += [
                    "--sdk=\(try sdk.getPath())",
                    "--target=\(target)",
                    "--skip-synthesized-members"
                ]
                let searchPaths = searchURLs.isEmpty ?
                    [FileManager.default.currentDirectory.path] :
                    searchURLs.map { $0.path }
                args += searchPaths.flatMap { ["-F=\($0)", "-I=\($0)"] }
            } else {
                let joinedArgs = buildToolArgs.joined(separator: " ")
                try ["--module", "--minimum-access-level", "--output-dir"].forEach { arg in
                    if joinedArgs.contains(arg) {
                        throw OptionsError(.localized(.errCfgSsgeArgs, arg))
                    }
                }
                args += buildToolArgs
            }
            logDebug("Calling swift-symbolgraph, args:")
            args.forEach { logDebug("  \($0)") }

            let results: Exec.Results
            if let injectedPath = ProcessInfo.processInfo.environment["J2_SWIFT_SYMBOLGRAPH_EXTRACT"] {
                logDebug("Using injected swift-symbolgraph-extract path: \(injectedPath)")
                results = Exec.run(injectedPath, args, stderr: .merge)
            } else {
                results = Exec.run("/usr/bin/env", ["swift", "symbolgraph-extract"] + args, stderr: .merge)
            }
            if results.terminationStatus != 0 {
                throw GatherError(.localized(.errCfgSsgeExec) + "\n\(results.failureReport)")
            }

            let mainSymbolFileURL = tmpDir.directoryURL.appendingPathComponent("\(moduleName).symbols.json")
            guard let mainSymbolData = try? Data(contentsOf: mainSymbolFileURL) else {
                throw GatherError(.localized(.errCfgSsgeMainMissing))
            }
            logDebug("Decoding main symbolgraph JSON for \(moduleName)")
            var dicts = [try GatherSymbolGraph.decode(data: mainSymbolData, extensionModuleName: moduleName)]

            // Extensions of things from other modules come in their own files, one per module.
            // Apple have put the foreign module in the filename and not the metadata...
            try tmpDir.directoryURL.filesMatching("*@*.symbols.json").forEach { url in
                guard let otherModuleName = url.lastPathComponent.re_match(#"@(.*?)\."#)?[1],
                    let otherSymbolData = try? Data(contentsOf: url) else {
                    logWarning(.localized(.wrnSsgeOddFilename, url.lastPathComponent))
                    return
                }
                logDebug("Decoding \(moduleName)'s extension symbolgraph JSON for \(otherModuleName)")
                try dicts.append(GatherSymbolGraph.decode(data: otherSymbolData,
                                                         extensionModuleName: otherModuleName))
            }

            logDebug("Gathering sourcekitten defs...")

            let defs = dicts.compactMap {
                GatherDef(sourceKittenDict: $0,
                          availability: availability)
            }

            return GatherModulePass(moduleName: moduleName,
                                    passIndex: 0,
                                    imported: false,
                                    files: defs.map { ("", $0) })
        }
    }
}
