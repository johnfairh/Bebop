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

    struct GatherSystem {
        let config: Config
        let gather: Gather

        init() {
            config = Config()
            gather = Gather(config: config)
        }

        func gather(_ opts: [String] = []) throws -> [GatherModulePass] {
            try config.processOptions(cliOpts: opts)
            return try gather.gather()
        }
    }

    func testRoundtrip() throws {
        let srcDir = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        guard let module = Module(spmArguments: [], spmName: "SpmSwiftModule2", inPath: srcDir.path) else {
            XCTFail()
            return
        }
        let sknJSON = module.docs.description

        let tmpFile = FileManager.default.temporaryFileURL()
        try sknJSON.write(to: tmpFile)

        let importedJSONDefs = try GatherSystem().gather([
            "-s", tmpFile.path,
            "--modules=SpmSwiftModule2"
        ]).json

        let directJSONDefs = try GatherSystem().gather([
            "--source-directory=\(srcDir.path)",
            "--modules=SpmSwiftModule2"
        ]).json

        XCTAssertEqual(directJSONDefs, importedJSONDefs)
    }

    func testImportErrors() throws {
        let tmpFile = FileManager.default.temporaryFileURL()

        try "Not JSON".write(to: tmpFile)
        AssertThrows(try GatherSystem().gather(["-s", tmpFile.path]), NSError.self)

        try "{}".write(to: tmpFile)
        AssertThrows(try GatherSystem().gather(["-s", tmpFile.path]), OptionsError.self)

        try "[{}]".write(to: tmpFile)
        TestLogger.install()
        let passes = try GatherSystem().gather(["-s", tmpFile.path, "--module=M1"])
        XCTAssertEqual(1, passes.count)
        XCTAssertTrue(passes[0].files.isEmpty)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }
}
