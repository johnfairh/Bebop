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

    func test(_ opts: String..., jobs expected: [GatherJob]) throws {
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
        try OptsSystem().test(jobs: [.swift(moduleName: nil, srcDir: nil, buildTool: nil)])
    }

    func testModule() throws {
        try OptsSystem().test("--module", "Test", jobs: [.swift(moduleName: "Test", srcDir: nil, buildTool: nil)])
    }

    func testCwd() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let system = OptsSystem()
        try system.test("--module", "Test", "--source-directory", cwd,
                        jobs: [.swift(moduleName: "Test", srcDir: URL(fileURLWithPath: cwd), buildTool: nil)])
    }

    // Run swift job in the Spm fixtures via srcdir.  Sniff results only.
    func testSpmSwift() throws {
        let swiftTestURL = fixturesURL.appendingPathComponent("SpmSwiftModule")
        let system = System()
        try system.config.processOptions(cliOpts: ["--source-directory", swiftTestURL.path])
        let gatherModules = try system.gather.gather()
        let json = gatherModules.json

        let sniffStr = #""key.usr" : "s:14SpmSwiftModuleAAV4textSSvp""#
        XCTAssertTrue(json.re_isMatch(sniffStr))
    }

    // Run swift job in the Xcode fixtures via chdir.  Sniff results only.
    func testXcodeSwift() throws {
        #if !os(Linux)
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

    // Run gather in a fake directory, check error.
    func testSwiftJobFailure() throws {
        try TemporaryDirectory.withNew {
            let system = System()
            try system.config.processOptions(cliOpts: [])
            AssertThrows(try system.gather.gather(), OptionsError.self)
        }
    }

    // Come back here later on to test multipass and merging.
}
