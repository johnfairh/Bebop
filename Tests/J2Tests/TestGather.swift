//
//  TestGather.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

// For testing config -> jobs
private struct OptsSystem {
    let config: Config
    let gatherOpts: GatherOpts

    init() {
        config = Config()
        gatherOpts = GatherOpts(config: config)
    }

    func test(_ opts: [String] = [], jobs expected: [GatherJob]) throws {
        try config.processOptions(cliOpts: opts)
        check(jobs: expected)
    }

    func test(_ yaml: String, jobs expected: [GatherJob]) throws {
        try useConfigFile(yaml)
        check(jobs: expected)
    }

    func useConfigFile(_ yaml: String) throws {
        let tmpDir = try TemporaryDirectory()
        let configFile = tmpDir.directoryURL.appendingPathComponent("j2.yaml")
        try yaml.write(to: configFile)
        try config.processOptions(cliOpts: ["--config=\(configFile.path)"])
    }

    func check(jobs expected: [GatherJob]) {
        let actual = gatherOpts.jobs
        XCTAssertEqual(expected.count, actual.count)
        zip(expected, actual).enumerated().forEach { idx, el in
            XCTAssertEqual(el.0, el.1, "Idx \(idx)")
        }
    }
}

private struct System {
    let config: Config
    let gather: Gather

    init() {
        config = Config()
        gather = Gather(config: config)
    }
}

class TestGather: XCTestCase {
    override func setUp() {
        initResources()
    }

    func testDefault() throws {
        try OptsSystem().test(jobs: [.swift(moduleName: nil,
                                            srcDir: nil,
                                            buildTool: nil,
                                            buildToolArgs: [],
                                            availability: Gather.Availability())])
    }

    func testModule() throws {
        try OptsSystem().test(["--module", "Test"], jobs: [.swift(moduleName: "Test",
                                                                  srcDir: nil,
                                                                  buildTool: nil,
                                                                  buildToolArgs: [],
                                                                  availability: Gather.Availability())])
    }

    func testBuildToolArgs() throws {
        let expected = GatherJob.swift(moduleName: nil,
                                       srcDir: nil,
                                       buildTool: nil,
                                       buildToolArgs: ["aa", "bb", "cc"],
                                       availability: Gather.Availability())
        try [ ["--build-tool-arguments", "aa,bb,cc"],
              ["-b", "aa", "-b", "bb", "--build-tool-arguments", "cc"] ].forEach { opts in
            try OptsSystem().test(opts, jobs: [expected])
        }
    }

    func testCwd() throws {
        let cwd = FileManager.default.currentDirectory
        let system = OptsSystem()
        // Weirdness here to work around Linux URL incompatibility.  How can anyone mess this up.
        let expectedSrcDir = URL(fileURLWithPath: cwd.path, relativeTo: cwd)
        let expected: GatherJob = .swift(moduleName: "Test",
                                         srcDir: expectedSrcDir,
                                         buildTool: nil,
                                         buildToolArgs: [],
                                         availability: Gather.Availability())
        try system.test(["--module", "Test", "--source-directory", cwd.path], jobs: [expected])
    }

    // Run swift job in the Spm fixtures via srcdir.  Sniff results only.
    func testSpmSwift() throws {
        let swiftTestURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let system = System()
        try system.config.processOptions(cliOpts: ["--source-directory", swiftTestURL.path])
        let gatherModules = try system.gather.gather()
        let json = gatherModules.json

        let sniffStr = #""key.usr" : "s:14SpmSwiftModuleAAV4textSSvp""#
        XCTAssertTrue(json.re_isMatch(sniffStr))
    }

    // Run swift job in the Xcode fixtures via chdir.  Sniff results only.
    func testXcodeSwift() throws {
        #if os(macOS)
        let xcodeTestURL = fixturesURL.appendingPathComponent("XcodeSwiftModule")
        try xcodeTestURL.withCurrentDirectory {
            let system = System()
            try system.config.processOptions(cliOpts: [])
            let gatherModules = try system.gather.gather()
            let json = gatherModules.json

            let sniffStr = #""key.name" : "someKindOfFunction\(\)""#
            XCTAssertTrue(json.re_isMatch(sniffStr))
        }
        #endif
    }

    // Run gather in a fake directory, check errors.
    func testSwiftJobFailure() throws {
        let cliOpts = [ [],
                        ["--build-tool", "xcodebuild"],
                        ["--build-tool", "xcodebuild", "--module", "Butter"]]
        try cliOpts.forEach { opts in
            try TemporaryDirectory.withNew {
                let system = System()
                try system.config.processOptions(cliOpts: opts)
                AssertThrows(try system.gather.gather(), GatherError.self)
            }
        }
    }

    // Auto detect build tool

    private func doEmptyFailingBuild(cliOpts: [String] = [], touchFile: String? = nil, expectSpm: Bool) throws {
        try TemporaryDirectory.withNew {
            if let touchFile = touchFile {
                let rc = FileManager.default.createFile(atPath: touchFile, contents: nil)
                XCTAssertTrue(rc)
            }
            let system = System()
            try system.config.processOptions(cliOpts: cliOpts)
            do {
                _ = try system.gather.gather()
                XCTFail("Can't succeed, no project")
            } catch let error as GatherError {
                if expectSpm {
                    XCTAssertTrue(error.description.re_isMatch("swift build"))
                } else {
                    XCTAssertTrue(error.description.re_isMatch("xcodebuild"))
                }
            }
        }
    }

    func testSpmDefault() throws {
        try doEmptyFailingBuild(cliOpts: [], expectSpm: true)
    }

    func testXcodebuildWithArgs() throws {
        #if os(macOS)
        try doEmptyFailingBuild(cliOpts: ["-b", "-workspace,../My.xcworkspace"], expectSpm: false)
        try doEmptyFailingBuild(cliOpts: ["-b", "-project,../My.xcodeproj"], expectSpm: false)
        #endif
    }

    func testXcodebuildWithFiles() throws {
        #if os(macOS)
        try doEmptyFailingBuild(touchFile: "my.xcodeproj", expectSpm: false)
        try doEmptyFailingBuild(touchFile: "my.xcworkspace", expectSpm: false)
        #endif
    }

    // Multi-module

    func testMultiModule() throws {
        let system = OptsSystem()
        try system.test(["--modules=M1,M2"], jobs: [
            .swift(moduleName: "M1", srcDir: nil, buildTool: nil, buildToolArgs: [], availability: Gather.Availability()),
            .swift(moduleName: "M2", srcDir: nil, buildTool: nil, buildToolArgs: [], availability: Gather.Availability())
        ])
    }

    func testRepeatedMultiModule() throws {
        let system = OptsSystem()
        AssertThrows(try system.test(["--modules=M1,M1"], jobs: []), OptionsError.self)
    }

    // custom_modules

    // Basic multi-module
    func testCustomModulesSimple() throws {
        let yaml = """
                   custom_modules:
                    - module: M1
                    - module: M2
                   """
        let system = OptsSystem()
        try system.test(yaml, jobs: [
            .swift(moduleName: "M1", srcDir: nil, buildTool: nil, buildToolArgs: [], availability: Gather.Availability()),
            .swift(moduleName: "M2", srcDir: nil, buildTool: nil, buildToolArgs: [], availability: Gather.Availability())
        ])
    }

    // Passes, cascade and override
    func testCustomModulesCascade() throws {
        TestLogger.uninstall()
        let yaml = """
                   debug: true
                   build_tool_arguments: [f1]
                   custom_modules:
                    - module: M1
                    - module: M2
                      ignore_availability_attr: true
                      passes:
                        - build_tool_arguments: [f2]
                        - build_tool_arguments: [f3]
                   """
        let system = OptsSystem()
        let defaultAvail = Gather.Availability()
        let modifiedAvail = Gather.Availability(defaults: [], ignoreAttr: true)
        try system.test(yaml, jobs: [
            .swift(moduleName: "M1", srcDir: nil, buildTool: nil, buildToolArgs: ["f1"], availability: defaultAvail),
            .swift(moduleName: "M2", srcDir: nil, buildTool: nil, buildToolArgs: ["f2"], availability: modifiedAvail),
            .swift(moduleName: "M2", srcDir: nil, buildTool: nil, buildToolArgs: ["f3"], availability: modifiedAvail)
        ])
    }

    // Error cases
    func testCustomModulesErrors() throws {
        // module + custom_modules
        let yaml1 = "module: M1\ncustom_modules:\n - module: M2"
        let system1 = OptsSystem()
        AssertThrows(try system1.useConfigFile(yaml1), OptionsError.self)

        // module missing
        let yaml2 = "custom_modules:\n - build_tool: spm"
        let system2 = OptsSystem()
        AssertThrows(try system2.useConfigFile(yaml2), OptionsError.self)

        // custom_modules not sequence
        let yaml3 = "custom_modules: whaat"
        let system3 = OptsSystem()
        AssertThrows(try system3.useConfigFile(yaml3), OptionsError.self)
    }
}
