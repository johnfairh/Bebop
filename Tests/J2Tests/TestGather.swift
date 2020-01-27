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
private struct System {
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

class TestGather: XCTestCase {
    override func setUp() {
        initResources()
    }

    func FAILS_testDefault() throws {
        try System().test(jobs: [.swift(moduleName: nil, srcDir: nil)])
    }

    func testModule() throws {
        try System().test("--module", "Test", jobs: [.swift(moduleName: "Test", srcDir: nil)])
    }

    func testCwd() throws {
        let cwd = FileManager.default.currentDirectoryPath
        let system = System()
        try system.test("--module", "Test", "--source-directory", cwd, jobs: [.swift(moduleName: "Test", srcDir: URL(fileURLWithPath: cwd))])
        XCTAssertEqual(cwd, system.gatherOpts.configFileSearchStart?.path)
    }

    // Run swift job in the Spm fixtures via srcdir.  Sniff results only.  JSON non-empty, regexp a couple things.
    // Run swift job in the Xcode fixtures via chdir.  Sniff results only. ditto.
    // Run gather in a fake directory, check error.
    // Add a pipeline e2e test against the spm fixtures.
    // Come back here later on to test multipass and merging.
}
