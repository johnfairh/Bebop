//
//  TestGatherPodspec.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
import Foundation
@testable import BebopLib

// Tests for podspec import
// macos only for the meat of it...

private class JobSystem {
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

private class PassSystem{
    let config: Config
    let gather: Gather

    init() {
        config = Config()
        gather = Gather(config: config)
    }

    func run(_ args: [String]) throws -> [GatherModulePass] {
        try config.processOptions(cliOpts: args)
        return try gather.gather()
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
        AssertThrows(try JobSystem().run(["--podspec=/Not/Exist"]), .errPathNotExist)

        // bad combo (module)
        AssertThrows(try JobSystem().run(["--podspec=\(podspecURL.path)", "--modules=M1,M2"]), .errCfgPodspecOuter)

        // bad combo (build tool)
        AssertThrows(try JobSystem().run(["--podspec=\(podspecURL.path)", "--build-tool=spm"]), .errCfgPodspecBuild)
    }

    private func checkBadYaml(_ yaml: String, args: [String] = [], _ key: L10n.Localizable) throws {
        let tmpURL = FileManager.default.temporaryFileURL()
        try yaml.write(to: tmpURL)
        AssertThrows(try JobSystem().run(args + ["--config=\(tmpURL.path)"]), key)
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
        let baseJob = try JobSystem().run(["--podspec", podspecURL.path])
        XCTAssertEqual(baseJob, GatherJob(podspecTitle: "", moduleName: nil, podspecURL: podspecURL, podSources: []))

        let modJob = try JobSystem().run(["--podspec", podspecURL.path, "--modules=M1"])
        XCTAssertEqual(modJob, GatherJob(podspecTitle: "", moduleName: "M1", podspecURL: podspecURL, podSources: []))

        let srcJob = try JobSystem().run(["--podspec", podspecURL.path, "--pod-sources=A,B,C"])
        XCTAssertEqual(srcJob, GatherJob(podspecTitle: "", moduleName: nil, podspecURL: podspecURL, podSources: ["A", "B", "C"]))
    }

    #if os(macOS)
    // MARK: Ruby-level failures

    func testModuleMismatch() throws {
        AssertThrows(try PassSystem().run(["--podspec", podspecURL.path, "--modules=Fred"]), .errPodspecModulename)
    }

    func testBadPodspec() throws {
        let badFileURL = FileManager.default.temporaryFileURL()
        try "Not a podspec".write(to: badFileURL)

        AssertThrows(try PassSystem().run(["--podspec", badFileURL.path]), .errPodspecFailed)
    }

    // MARK: Metadata

    func testMetadata() throws {
        let system = PassSystem()
        let _ = try system.run(["--podspec", podspecURL.path])
        XCTAssertEqual("0.1", system.config.published.docsVersion)
        let module = system.config.published.module("Pod")
        guard let codeHostFilePrefix = module.codeHostFilePrefix else {
            XCTFail()
            return
        }
        XCTAssertTrue(codeHostFilePrefix.hasPrefix("https://github.com/johnfairh"))
    }

    // Good-path (to files-json) covered in TestProducts

    #endif

    // MARK: Availability

    func testAvailabilityMapping() throws {
        let job1 = try JobSystem().run(["--podspec", podspecURL.path])
        guard case let .podspec(_, podspecJob1) = job1 else {
            XCTFail()
            return
        }
        XCTAssertEqual(Gather.Availability(defaults: ["V"]), podspecJob1.customizeAvailability(version: "V"))

        let job2 = try JobSystem().run(["--podspec", podspecURL.path, "--availability=Always"])
        guard case let .podspec(_, podspecJob2) = job2 else {
            XCTFail()
            return
        }
        XCTAssertEqual(Gather.Availability(defaults: ["Always"]), podspecJob2.customizeAvailability(version: "V"))
    }
}
