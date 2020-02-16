//
//  TestGatherObjC.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

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

class TestGatherObjC: XCTestCase {
    override func setUp() {
        initResources()
    }

    #if !os(macOS)
    func testNoObjC() {
        let tmpDir = try TemporaryDirectory()
        let tmpFile = try tmpDir.createFile(name: "test.h")
        try "extern int fred;".write(to: tmpFile)

        let system = System()
        AssertThrows(try system.configure(["--objc-header-file=\(tmpFile.path)"]), OptionsError.self)
    }
    #else


    private func checkError(_ cliOpts: [String], line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(cliOpts), OptionsError.self, line: line)
    }

    private func checkNotImplemented(_ cliOpts: [String], line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(cliOpts), NotImplementedError.self, line: line)
    }

    func testBadOptions() {
        checkError(["--objc", "--build-tool=spm"])
        checkError(["--objc-direct"])
        checkError(["--objc-sdk=macosx"])
        checkError(["--objc-include-paths=/"])
        checkNotImplemented(["--objc-header=/foo.h", "--build-tool=spm"])
    }

    private func checkJob(_ cliOpts: [String], _ expectedJob: GatherJob, line: UInt = #line) throws {
        let system = System()
        let job = try system.configure(cliOpts)
        XCTAssertEqual(expectedJob, job, line: line)
    }

    func testJobOptions() throws {
        let tmpDir = try TemporaryDirectory()
        let tmpFile = try tmpDir.createFile(name: "test.h")
        try "extern int fred;".write(to: tmpFile)

        let tmpDirURL = URL(fileURLWithPath: tmpDir.directoryURL.path,
                            relativeTo: FileManager.default.currentDirectory)

        TestLogger.install()
        try checkJob(["--objc-header-file=\(tmpFile.path)"],
                 .objcDirect(moduleName: "Module",
                             srcDir: nil,
                             headerFile: tmpFile,
                             includePaths: [],
                             sdk: .macosx,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

        try checkJob(["--objc-header-file=\(tmpFile.path)", "--module=MyMod"],
                 .objcDirect(moduleName: "MyMod",
                             srcDir: nil,
                             headerFile: tmpFile,
                             includePaths: [],
                             sdk: .macosx,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))

        try checkJob(["--objc-header-file=\(tmpFile.path)",
                      "--objc-sdk=iphoneos",
                      "--objc-include-paths=\(tmpDir.directoryURL.path)"],
                 .objcDirect(moduleName: "Module",
                             srcDir: nil,
                             headerFile: tmpFile,
                             includePaths: [tmpDirURL],
                             sdk: .iphoneos,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))
    }

    #endif /* macOS */
}
