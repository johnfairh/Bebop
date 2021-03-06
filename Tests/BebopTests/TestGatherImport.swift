//
//  TestGatherImport.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib
import SourceKittenFramework

// SourceKitten/GatherDecl import tests

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

private class GatherSystem {
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


class TestGatherImport: XCTestCase {
    override func setUp() {
        initResources()
    }

    private func checkConfigError(_ opts: [String], _ key: L10n.Localizable, line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(opts), key, line: line)
    }

    private func checkJob(_ cliOpts: [String], _ expectedJob: GatherJob, line: UInt = #line) throws {
        let system = System()
        let job = try system.configure(cliOpts)
        XCTAssertEqual(expectedJob, job, line: line)
    }

    private func checkJobs(_ cliOpts: [String], _ expectedJobs: [GatherJob], line: UInt = #line) throws {
        let system = System()
        try system.config.processOptions(cliOpts: cliOpts)
        let jobs = system.gatherOpts.jobs
        XCTAssertEqual(expectedJobs.count, jobs.count, line: line)
        XCTAssertEqual(expectedJobs, jobs, line: line)
    }

    // MARK: Sourcekitten Syntax

    func testSknCliErrors() throws {
        checkConfigError(["-s", "badfile"], .errPathNotExist)

        let tmpDir = try TemporaryDirectory()
        let srcFileURL = tmpDir.directoryURL.appendingPathComponent("m.json")
        try "[]".write(to: srcFileURL)

        checkConfigError(["-s", srcFileURL.path, "--build-tool=spm"], .errCfgSknBuildTool)
        checkConfigError(["-s", srcFileURL.path, "--objc-header-file=\(srcFileURL.path)"], .errCfgSknBuildTool)
        checkConfigError(["-s", srcFileURL.path, "--modules=A,B,C"], .errCfgSknMultiModules)

        let cfgFileURL = tmpDir.directoryURL.appendingPathComponent("bebop.yaml")
        try "custom_modules:\n  - name: Fred".write(to: cfgFileURL)
        checkConfigError(["-s", srcFileURL.path, "--config=\(cfgFileURL.path)"], .errCfgSknCustomModules)
    }

    func testSknJobBuilding() throws {
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

    // MARK: Gather Syntax

    func testImportCliErrors() throws {
        checkConfigError(["--bebop-json-files", "badfile"], .errPathNotExist)

        let tmpDir = try TemporaryDirectory()
        let srcFileURL = tmpDir.directoryURL.appendingPathComponent("m.json")
        try "[]".write(to: srcFileURL)

        checkConfigError(["--bebop-json-files", srcFileURL.path, "--build-tool=spm"], .errCfgBebopJsonMutex)
        checkConfigError(["--bebop-json-files", srcFileURL.path, "--objc-header-file=\(srcFileURL.path)"], .errCfgBebopJsonMutex)
    }

    func testImportJobBuilding() throws {
        let tmpDir = try TemporaryDirectory()
        let srcFileURL = tmpDir.directoryURL.appendingPathComponent("m.json")
        try "[]".write(to: srcFileURL)

        try checkJob(["--bebop-json-files", srcFileURL.path],
                     .init(importTitle: "", moduleName: nil, passIndex: nil, fileURLs: [srcFileURL]))

        try checkJobs(["--bebop-json-files", srcFileURL.path, "--modules=M1,M2,M3"],
                      [.init(importTitle: "", moduleName: "M1", passIndex: nil, fileURLs: [srcFileURL]),
                       .init(importTitle: "", moduleName: "M2", passIndex: nil, fileURLs: [srcFileURL]),
                       .init(importTitle: "", moduleName: "M3", passIndex: nil, fileURLs: [srcFileURL])])

        let yaml = """
                   custom_modules:
                    - module: M1
                    - module: M2
                      passes:
                        - build_tool_arguments: [f2]
                        - build_tool_arguments: [f3]
                   """
        let configFileURL = tmpDir.directoryURL.appendingPathComponent("bebop.yaml")
        try yaml.write(to: configFileURL)

        try checkJobs(["--bebop-json-files", srcFileURL.path,
                       "--config", configFileURL.path],
                      [.init(importTitle: "", moduleName: "M1", passIndex: nil, fileURLs: [srcFileURL]),
                       .init(importTitle: "", moduleName: "M2", passIndex: 0, fileURLs: [srcFileURL]),
                       .init(importTitle: "", moduleName: "M2", passIndex: 1, fileURLs: [srcFileURL])])
    }

    // MARK: SourceKitten JSON

    private func createSourceKittenJSON(module: String) throws -> URL {
        let srcDir = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let module = Module(spmArguments: [], spmName: module, inPath: srcDir.path)!
        let sknJSON = module.docs.description
        let tmpFileURL = FileManager.default.temporaryFileURL()
        try sknJSON.write(to: tmpFileURL)
        return tmpFileURL
    }

    func testRoundtrip() throws {
        let srcDir = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        let tmpFile = try createSourceKittenJSON(module: "SpmSwiftModule2")

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
        AssertThrows(try GatherSystem().gather(["-s", tmpFile.path]), .errJsonDecode)

        try "[{}]".write(to: tmpFile)
        TestLogger.install()
        let passes = try GatherSystem().gather(["-s", tmpFile.path, "--module=M1"])
        XCTAssertEqual(1, passes.count)
        XCTAssertTrue(passes[0].files.isEmpty)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    // Hokey attribute resolution without source file...

    func testAttributes() throws {
        let tmpFileURL = try createSourceKittenJSON(module: "SpmSwiftModule6")
        let passes = try GatherSystem().gather(["-s", tmpFileURL.path])
        XCTAssertEqual(1, passes[0].files.count)
        let file = passes[0].files[0]
        let func1Def = file.1.children[0]
        XCTAssertEqual("withoutDocComment()", func1Def.sourceKittenDict.name)
        XCTAssertTrue(func1Def.swiftDeclaration!.declaration.text.hasPrefix("@discardableResult"))
        XCTAssertNil(func1Def.swiftDeclaration?.deprecation)

        let func2Def = file.1.children[1]
        XCTAssertEqual("withDocComment()", func2Def.sourceKittenDict.name)
        XCTAssertTrue(func2Def.swiftDeclaration!.declaration.text.hasPrefix("@discardableResult"))
        XCTAssertNotNil(func2Def.swiftDeclaration?.deprecation)
    }

    // MARK: Gather JSON

    func checkRoundTrip(_ cliArgs: [String], line: UInt = #line) throws {
        let tmpDir = try TemporaryDirectory()

        let realPasses = try GatherSystem().gather(cliArgs)
        let realJSONURL = tmpDir.directoryURL.appendingPathComponent("files.json")
        let realJSON = realPasses.json
        try realJSON.write(to: realJSONURL)

        let importedPasses = try GatherSystem().gather(["--bebop-json-files=\(realJSONURL.path)"])
        let importedJSONURL = tmpDir.directoryURL.appendingPathComponent("imported-decls.json")
        let importedJSON = importedPasses.json
        try importedJSON.write(to: importedJSONURL)

        if importedJSON != realJSON {
            print("diff \(realJSONURL.path) \(importedJSONURL.path)")
            XCTFail()
        }
    }

    func testImportRoundTrip() throws {
        try checkRoundTrip([
            "--source-directory=\(fixturesURL.appendingPathComponent("SpmSwiftPackage").path)",
            "--modules=SpmSwiftModule"
        ])

        #if os(macOS)
        let headerURL = fixturesURL
            .appendingPathComponent("ObjectiveC")
            .appendingPathComponent("Header.h")
        try checkRoundTrip(["--objc-header-file", headerURL.path])
        #endif
    }

    func testImportFiltering() throws {
        let classA = SourceKittenDict.mkClass(name: "ClassA")
        let moduleA = SourceKittenDict.mkFile()
            .with(children: [classA])
            .asGatherDef()
            .asPass(moduleName: "ModA")
        let classB = SourceKittenDict.mkClass(name: "ClassB")
        let moduleBpass0 = SourceKittenDict.mkFile()
            .with(children: [classB])
            .asGatherDef()
            .asPass(moduleName: "ModB", passIndex: 0)
        let classC = SourceKittenDict.mkClass(name: "ClassC")
        let moduleBpass1 = SourceKittenDict.mkFile()
            .with(children: [classC])
            .asGatherDef()
            .asPass(moduleName: "ModB", passIndex: 1)

        let tmpDir = try TemporaryDirectory()
        let jsonURL = tmpDir.directoryURL.appendingPathComponent("files.json")
        try [moduleA, moduleBpass0, moduleBpass1].json.write(to: jsonURL)

        // Unfiltered
        let unfiltered = try GatherSystem().gather(["--bebop-json-files=\(jsonURL.path)"])
        XCTAssertEqual(3, unfiltered.count)

        // Module
        let moduleFiltered = try GatherSystem().gather([
            "--bebop-json-files=\(jsonURL.path)",
            "--modules=ModA"
        ])
        XCTAssertEqual(1, moduleFiltered.count)
        XCTAssertEqual("ClassA", moduleFiltered[0].files[0].1.children[0].sourceKittenDict.name)

        // Module + Pass
        let yaml = """
                   custom_modules:
                     - module: ModB
                       passes:
                         - bebop_json_files: \(jsonURL.path)
                         - bebop_json_files: \(jsonURL.path)
                   """
        let configURL = tmpDir.directoryURL.appendingPathComponent("bebop.yaml")
        try yaml.write(to: configURL)
        let passFiltered = try GatherSystem().gather(["--config=\(configURL.path)"])
        XCTAssertEqual(2, passFiltered.count)
    }

    func testBadImportJson() throws {
        let tmpDir = try TemporaryDirectory()

        // Bad metadata
        let badMetadata = """
                          [{
                            "path" : {
                             "not" : "metadata"
                            }
                          }]
                          """
        let badMetaURL = tmpDir.directoryURL.appendingPathComponent("bad.json")
        try badMetadata.write(to: badMetaURL)
        TestLogger.install()
        let passes = try GatherSystem().gather(["--bebop-json-files=\(badMetaURL.path)"])
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
        XCTAssertTrue(passes.isEmpty)

        // Bad version number
        let badVersion = """
                          [{
                            "path" : {
                              "key.bb.module_name" : "Mod",
                              "key.bb.pass_index" : 0,
                              "key.bb.version" : "10.1",
                            }
                          }]
                          """
        try badVersion.write(to: badMetaURL)
        TestLogger.install()
        let passes2 = try GatherSystem().gather(["--bebop-json-files=\(badMetaURL.path)"])
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
        XCTAssertTrue(passes2.isEmpty)
    }
}
