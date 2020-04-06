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

    #if os(macOS) // until we have a real toolchain

    func testModuleLocation() throws {
        guard TestSymbolGraph.isMyLaptop else { return }

        TestSymbolGraph.useCustom(); defer { TestSymbolGraph.reset() }

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

        let srcDirJSON = srcDirPasses.json
        let cwdJSON = cwdPasses.json

        if srcDirJSON != cwdJSON {
            let srcDirJSONURL = FileManager.default.temporaryFileURL()
            try srcDirJSON.write(to: srcDirJSONURL)

            let cwdJSONURL = FileManager.default.temporaryFileURL()
            try cwdJSON.write(to: cwdJSONURL)

            print("diff \(srcDirJSONURL.path) \(cwdJSONURL.path)")
            XCTFail()
        }
    }
    #endif

    // MARK: Tool misbehaviours

    func testToolFailures() throws {
        TestSymbolGraph.useCustom(); defer { TestSymbolGraph.reset() }

        // Straight failure
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), GatherError.self)

        // No main symbols file
        TestSymbolGraph.useCustom(path: "/usr/bin/true")
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), GatherError.self)
    }
}
