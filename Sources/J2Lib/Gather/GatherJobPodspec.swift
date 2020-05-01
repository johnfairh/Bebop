//
//  GatherJobPodspec.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Podspec

/// Shell out to a Ruby script to unpack the podspec build environment.
/// Then come back here and spin off Swift jobs for each target.
extension GatherJob {
    struct Podspec: Equatable {
        let moduleName: String?
        let podspecURL: URL
        let podSources: [String]
        let availability: Gather.Availability

        func execute() throws -> [GatherModulePass] {
            let tmpDir = try TemporaryDirectory()
            return try withExtendedLifetime(tmpDir) {
                let rsp = try unpack(tmpDirURL: tmpDir.directoryURL)
                if let moduleName = moduleName,
                    moduleName != rsp.module {
                    throw J2Error(.errPodspecModulename, moduleName, rsp.module)
                }
                return try rsp.targets
                    // sort for json reproducibility
                    .sorted(by: { $0.1 < $1.1 })
                    .map { (targetName, version) -> GatherModulePass in
                        logDebug("Podspec: spinning off Swift job for target \(targetName)")
                        let swiftJob = Swift(moduleName: rsp.module,
                                             srcDir: URL(fileURLWithPath: rsp.root),
                                             buildTool: .xcodebuild,
                                             buildToolArgs: ["-target", targetName],
                                             availability: customizeAvailability(version: version))
                        return try swiftJob.execute()
                    }
                    .map {
                        GatherModulePass(moduleName: $0.moduleName,
                                         version: rsp.version,
                                         codeHostFileURL: rsp.github_prefix,
                                         passIndex: $0.passIndex,
                                         imported: $0.imported,
                                         files: $0.files)
                    }
            }
        }

        /// If we haven't been told to hard-code availability, make something up from the cocoapods info.
        /// `version`is like "iOS 8.0+"
        func customizeAvailability(version: String) -> Gather.Availability {
            guard availability.defaults.isEmpty else {
                return availability
            }
            return Gather.Availability(defaults: [version],
                                       ignoreAttr: availability.ignoreAttr)
        }

        /// Invoke the Ruby script to prepare the podspec build environment and tell us about it
        func unpack(tmpDirURL: URL) throws -> Rsp {
            logInfo(.msgUnpackPodspec, podspecURL.lastPathComponent)

            let reqURL = tmpDirURL.appendingPathComponent("req.json")
            let rspURL = tmpDirURL.appendingPathComponent("rsp.json")
            let req = Req(podspec: podspecURL.path,
                          tmpdir: tmpDirURL.path,
                          response: rspURL.path,
                          sources: podSources)
            try JSON.encode(req).write(to: reqURL)
            logDebug("Podspec: request: \(req)")

            let scriptURL = Resources.shared.bundle.resourceURL!.appendingPathComponent("podsetup.rb")
            let result = Exec.run("/usr/bin/env", "ruby", "--", scriptURL.path, reqURL.path, stderr: .merge)
            guard result.terminationStatus == 0 else {
                throw J2Error(.errPodspecFailed, result.failureReport)
            }
            let rsp = try JSONDecoder().decode(Rsp.self, from: Data(contentsOf: rspURL))
            logDebug("Podspec: respose: \(rsp)")
            return rsp
        }

        struct Req: Encodable {
            let podspec: String
            let tmpdir: String
            let response: String
            let sources: [String]
        }

        struct Rsp: Decodable {
            let module: String
            let version: String
            let github_prefix: String?
            let root: String
            let targets: [String : String]
        }
    }
}
