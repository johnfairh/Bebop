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

    // Come back here later on to test multipass and merging.
}
