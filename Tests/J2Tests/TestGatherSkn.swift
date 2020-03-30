//
//  TestGatherSkn.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import SourceKittenFramework

// SourceKitten import tests

private class System {
    let config: Config
    let gatherOpts: GatherOpts
    init() {
        config = Config()
        gatherOpts = GatherOpts(config: config)
    }
    func configure(_ cliOpts: [String]) throws -> GatherJob {
        try config.processOptions(cliOpts: cliOpts)
        let jobs = gatherOpts.jobs
        XCTAssertEqual(1, jobs.count)
        return gatherOpts.jobs.first!
    }
}

class TestGatherSkn: XCTestCase {
    override func setUp() {
        initResources()
    }

    private func checkConfigError(_ opts: [String], line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(opts), OptionsError.self, line: line)
    }

    func testCliErrors() throws {
        checkConfigError(["-s", "badfile"])

        let tmpDir = try TemporaryDirectory()
        let srcFileURL = tmpDir.directoryURL.appendingPathComponent("m.json")
        try "[]".write(to: srcFileURL)

        checkConfigError(["-s", srcFileURL.path, "--build-tool=spm"])
        checkConfigError(["-s", srcFileURL.path, "--objc-header-file=\(srcFileURL.path)"])
        checkConfigError(["-s", srcFileURL.path, "--modules=A,B,C"])

        let cfgFileURL = tmpDir.directoryURL.appendingPathComponent("j2.yaml")
        try "custom_modules:\n  - name: Fred".write(to: cfgFileURL)
        checkConfigError(["-s", srcFileURL.path, "--config=\(cfgFileURL.path)"])
    }

    private func checkJob(_ cliOpts: [String], _ expectedJob: GatherJob, line: UInt = #line) throws {
        let system = System()
        let job = try system.configure(cliOpts)
        XCTAssertEqual(expectedJob, job, line: line)
    }

    func testJobBuilding() throws {
        let tmpDir = try TemporaryDirectory()
        let srcFileURL = tmpDir.directoryURL.appendingPathComponent("m.json")
        try "[]".write(to: srcFileURL)

        try checkJob(["-s", srcFileURL.path, "--modules=M1"],
                     .init(sknImportTitle: "", moduleName: "M1", fileURLs: [srcFileURL]))

        TestLogger.install()
        try checkJob(["-s", srcFileURL.path],
                     .init(sknImportTitle: "", moduleName: "Module", fileURLs: [srcFileURL]))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }
}
