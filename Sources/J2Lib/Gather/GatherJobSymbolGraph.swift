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
// -F=<srcDir ?? pwd>
// -I=<srcDir ?? pwd>

extension GatherJob {
    /// Job to run `swift symbolgraph-extract` on some module and massage the created JSON
    /// into something approximating what SourceKit would create, so that we can feed into that codepath.
    struct SymbolGraph: Equatable {
        let moduleName: String
        let srcDir: URL?
        let buildToolArgs: [String]
        let sdk: Gather.Sdk
        let target: String
        let availability: Gather.Availability

        /// This layer's job is to manage the CLI args, invoke the program, figure out what it created,
        /// and pass the JSON over to GatherSymbolGraph utils.
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
                let includeDir = (srcDir ?? FileManager.default.currentDirectory).path
                args += ["-F=\(includeDir)", "-I=\(includeDir)"]
            } else {
                try ["--module", "--minimum-access-level", "--output-dir"].forEach { arg in
                    if buildToolArgs.joined(separator: " ").contains(arg) {
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
            guard let mainSymbolJSON = try? String(contentsOf: mainSymbolFileURL) else {
                throw GatherError(.localized(.errCfgSsgeMainMissing))
            }

            var defs = [try GatherSymbolGraph.decode(moduleName: moduleName, json: mainSymbolJSON)]

            // Extensions of things from other modules come in their own files, one per module.
            // Apple have put the foreign module in the filename and not the metadata...
            try tmpDir.directoryURL.filesMatching("*@*.symbols.json").forEach { url in
                guard let otherModuleName = url.lastPathComponent.re_match(#"@(.*?)\."#)?[1],
                    let otherSymbolJSON = try? String(contentsOf: url) else {
                    logWarning(.localized(.wrnSsgeOddFilename, url.lastPathComponent))
                    return
                }
                try defs.append(GatherSymbolGraph.decode(moduleName: moduleName,
                                                         otherModuleName: otherModuleName,
                                                         json: otherSymbolJSON))
            }

            return GatherModulePass(moduleName: moduleName, passIndex: 0, imported: false, files: defs.map { ("", $0) })
        }
    }
}
