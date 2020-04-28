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
        AssertThrows(try System().run(["--build-tool=swift-symbolgraph"]), .errCfgSsgeModule)

        // bad triple
        AssertThrows(try System().run(["--symbolgraph-target=not-triple"]), .errCfgSsgeTriple)

        // invalid override
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=Foo",
            "--build-tool-arguments=--minimum-access-level=public"
        ]), .errCfgSsgeArgs)
    }

    // MARK: Goodpath end-to-end running, srcdir

    // Actual output stability test in TestProducts

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
            "--source-directory=/Does/Not/Exist",
            "--symbolgraph-search-paths=\(binDirPath)"
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

        #if os(macOS)

        // Straight failure
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), .errCfgSsgeExec)

        // No main symbols file
        TestSymbolGraph.useCustom(path: "/usr/bin/true")
        AssertThrows(try System().run([
            "--build-tool=swift-symbolgraph",
            "--modules=NotAModule"
        ]), .errCfgSsgeMainMissing)

        #endif
    }

    // MARK: Bad data detection

    func testDecodeFailure() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        AssertThrows(try GatherSymbolGraph.decode(data: data, extensionModuleName: "Mod"),
                     Swift.DecodingError.self)
    }

    private func checkBadData(_ json: String, warningCount: Int) throws {
        let data = json.data(using: .utf8)!
        TestLogger.install()
        let _ = try GatherSymbolGraph.decode(data: data, extensionModuleName: "Module")
        XCTAssertEqual(warningCount, TestLogger.shared.diagsBuf.count)
    }

    private func makeSymbolJSON(kindOuter: String = "swift.struct",
                                kindInner: String = "swift.method",
                                accessLevel: String = "internal",
                                availabilityKey: String = "isUnconditionallyDeprecated",
                                relKind: String = "memberOf",
                                constraintKind: String = "conformance",
                                relSourceUSR: String = "s:4ModA1SV1f1aSix_tSQRzlF") -> String {
        """
        {
          "metadata": { "generator": "Swift version 5.3-dev (LLVM aa70751bec, Swift 1331ac5940)" },
          "symbols": [{
              "kind": { "identifier": "\(kindOuter)" },
              "identifier": { "precise": "s:4ModA1SV" },
              "pathComponents": [ "S" ],
              "names": { "title": "S" },
              "declarationFragments": [
                { "spelling": "struct" },
                { "spelling": " " },
                { "spelling": "S" }
              ],
              "accessLevel": "\(accessLevel)",
              "availability": [ { "\(availabilityKey)": true } ],
              "swiftGenerics": {
                "constraints": [{
                  "kind": "\(constraintKind)",
                  "lhs": "T",
                  "rhs": "Equatable"
                }]
              }
          },{
              "kind": { "identifier": "\(kindInner)" },
              "identifier": { "precise": "s:4ModA1SV1f1aSix_tSQRzlF" },
              "pathComponents": [ "S", "f" ],
              "names": { "title": "f()" },
              "declarationFragments": [
                { "spelling": "func" },
                { "spelling": " " },
                { "spelling": "f()" }
              ],
              "accessLevel": "internal"
          }],
          "relationships": [{
              "kind": "\(relKind)",
              "source": "\(relSourceUSR)",
              "target": "s:4ModA1SV"
          }]
        }
        """
    }

    func testBadData() throws {
        // fine by default
        try checkBadData(makeSymbolJSON(), warningCount: 0)

        // bad sym kind
        try checkBadData(makeSymbolJSON(kindOuter: "special"), warningCount: 1)

        // bad access level
        try checkBadData(makeSymbolJSON(accessLevel: "special"), warningCount: 1)

        // bad rel kind
        try checkBadData(makeSymbolJSON(relKind: "partner"), warningCount: 1)

        // bad availability object
        try checkBadData(makeSymbolJSON(availabilityKey: "wibble"), warningCount: 1)

        // bad generic constraint object
        try checkBadData(makeSymbolJSON(constraintKind: "banana"), warningCount: 1)

        // bad relationship source
        try checkBadData(makeSymbolJSON(relSourceUSR: "missing"), warningCount: 1)
    }
}
