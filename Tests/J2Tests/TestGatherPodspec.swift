//
//  TestGatherPodspec.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import Foundation
@testable import J2Lib

// Tests for podspec import
// macos only for the meat of it...

private class System {
    let config: Config
    let gatherOpts: GatherOpts

    init() {
        config = Config()
        gatherOpts = GatherOpts(config: config)
    }

    func run(_ args: [String]) throws -> GatherJob {
        try config.processOptions(cliOpts: args)
        return gatherOpts.jobs.first!
    }
}

class TestGatherPodspec: XCTestCase {
    override func setUp() {
        initResources()
    }

    var podspecURL: URL {
        fixturesURL.appendingPathComponent("Pod")
            .appendingPathComponent("Pod.podspec")
    }

    // MARK: Config error paths

    func testCliErrors() throws {
        // no file
        AssertThrows(try System().run(["--podspec=/Not/Exist"]), .errPathNotExist)

        // bad combo (module)
        AssertThrows(try System().run(["--podspec=\(podspecURL.path)", "--modules=M1,M2"]), .errCfgPodspecOuter)

        // bad combo (build tool)
        AssertThrows(try System().run(["--podspec=\(podspecURL.path)", "--build-tool=spm"]), .errCfgPodspecBuild)
    }

    private func checkBadYaml(_ yaml: String, args: [String] = [], _ key: L10n.Localizable) throws {
        let tmpURL = FileManager.default.temporaryFileURL()
        try yaml.write(to: tmpURL)
        AssertThrows(try System().run(args + ["--config=\(tmpURL.path)"]), key)
    }

    func testYamlErrors() throws {
        let badModules = """
                         custom_modules:
                           - module: M1
                             build_tool: spm
                         """
        try checkBadYaml(badModules, args: ["--podspec", podspecURL.path], .errCfgPodspecOuter)

        let wrongLevel = """
                         custom_modules:
                           - module: M1
                             build_tool: spm
                             passes:
                               - podspec: \(podspecURL.path)
                         """
        try checkBadYaml(wrongLevel, .errCfgPodspecPass)
    }

    // MARK: Job generation

    func testJobGeneration() throws {
        let baseJob = try System().run(["--podspec", podspecURL.path])
        XCTAssertEqual(baseJob, GatherJob(podspecTitle: "", moduleName: nil, podspecURL: podspecURL, podSources: []))

        let modJob = try System().run(["--podspec", podspecURL.path, "--modules=M1"])
        XCTAssertEqual(modJob, GatherJob(podspecTitle: "", moduleName: "M1", podspecURL: podspecURL, podSources: []))

        let srcJob = try System().run(["--podspec", podspecURL.path, "--pod-sources=A,B,C"])
        XCTAssertEqual(srcJob, GatherJob(podspecTitle: "", moduleName: nil, podspecURL: podspecURL, podSources: ["A", "B", "C"]))
    }
}
