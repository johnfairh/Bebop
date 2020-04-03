//
//  TestGatherSymGraph.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

// Tests for symbolgraph-extract import

private class System {
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

class TestGatherSymGraph: XCTestCase {
    override func setUp() {
        initResources()
    }

    // MARK: CLI options

    func testArgChecks() throws {
        // no implicit module
        AssertThrows(try System().run(["--build-tool=swift-symbolgraph"]), OptionsError.self)

        // bad triple
        AssertThrows(try System().run(["--swift-symbolgraph-target=not-triple"]), OptionsError.self)

        // invalid override
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=Foo",
            "--build-tool-arguments=--minimum-access-level=public"
        ]), OptionsError.self)
    }

    // MARK: Goodpath end-to-end running, srcdir

    let toolPath = "/Users/johnf/project/swift-source/build/jfdev/swift-macosx-x86_64/bin/swift-symbolgraph-extract"

    var isMyLaptop: Bool {
        FileManager.default.fileExists(atPath: toolPath)
    }

    func useCustomTool(path: String? = nil) {
        let tool = path ?? "/Users/johnf/project/swift-source/build/jfdev/swift-macosx-x86_64/bin/swift-symbolgraph-extract"
        setenv("J2_SWIFT_SYMBOLGRAPH_EXTRACT", strdup(tool), 1)
    }
    func resetTool() {
        unsetenv("J2_SWIFT_SYMBOLGRAPH_EXTRACT")
    }

    #if os(macOS) // until we have a real toolchain

    func testModuleLocation() throws {
        guard isMyLaptop else { return }

        useCustomTool(); defer { resetTool() }

//        let binDirPath = try fixturesURL.appendingPathComponent("SpmSwiftPackage").withCurrentDirectory { () -> String in
//            let buildResult = Exec.run("/usr/bin/env", "swift", "build")
//            XCTAssertEqual(0, buildResult.terminationStatus, buildResult.failureReport)
//            let binPathResult = Exec.run("/usr/bin/env", "swift", "build", "--show-bin-path")
//            guard let binPath = binPathResult.successString else {
//                XCTFail(binPathResult.failureReport)
//                return ""
//            }
//            return binPath
//        }
        let binDirPath = fixturesURL.appendingPathComponent("Swift53").path

        let srcDirPasses = try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=SpmSwiftModule",
            "--source-directory=\(binDirPath)"
        ])

        let cwdPasses = try URL(fileURLWithPath: binDirPath).withCurrentDirectory {
            try System().run(["--build-tool=swift-symbolgraph", "--modules=SpmSwiftModule"])
        }

        XCTAssertEqual(srcDirPasses.json, cwdPasses.json)
    }
    #endif

    // MARK: Tool misbehaviours

    func testToolFailures() throws {
        useCustomTool(); defer { resetTool() }

        // Straight failure
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), GatherError.self)

        // No main symbols file
        useCustomTool(path: "/usr/bin/true")
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), GatherError.self)
    }

}
