//
//  TestConfig.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate class System: Configurable {
    struct DummyComponent: Configurable {}

    let config = Config()
    let dummy = DummyComponent()
    let nameOpt = StringOpt(l: "name")
    let hiddenOpt = StringOpt(l: "eyecatcher").hidden
    var checkOptionsCalled = false
    let aliasOpt: AliasOpt

    init() {
        aliasOpt = AliasOpt(realOpt: nameOpt, l: "moniker")
    }

    func configure(cliOpts: String...) throws {
        config.register(self)
        config.register(dummy)

        try config.processOptions(cliOpts: cliOpts)
    }

    func checkOptions() throws {
        checkOptionsCalled = true
    }
}

class TestConfig: XCTestCase {

    override func setUp() {
        TestLogger.uninstall()
        initResources()
    }

    // 1. register, propagates CLI opts and calls checkOpts
    func testBasic() throws {
        TestLogger.install()
        TestLogger.shared.expectNothing = true

        let system = System()
        try system.configure()

        XCTAssertTrue(system.checkOptionsCalled)
        XCTAssertFalse(system.nameOpt.configured)

        XCTAssertFalse(system.config.performConfigCommand())
    }

    // 2a Config file - explicit and cwd
    func testConfigFile() throws {
        let tmpDir = try TemporaryDirectory()
        let configFile = try tmpDir.createFile(name: ".j2.yaml")
        try "name: fred".write(to: configFile)

        do {
            let system = System()
            try system.configure(cliOpts: "--config", configFile.path)
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertTrue(system.nameOpt.configured)
            XCTAssertEqual("fred", system.nameOpt.value)
        }

        try tmpDir.directoryURL.withCurrentDirectory {
            let system = System()
            try system.configure()
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertTrue(system.nameOpt.configured)
            XCTAssertEqual("fred", system.nameOpt.value)
        }
    }

    // 2b Config file - Check j2->jazzy and parent-searching
    func testConfigFileSearch() throws {
        let tmpDir = try TemporaryDirectory()
        let tmpSubDir = try tmpDir.createDirectory()
        let j2Config = try tmpDir.createFile(name: ".j2.yaml")
        try "name: barney".write(to: j2Config)
        let jazzyConfig = try tmpSubDir.createFile(name: ".jazzy.yaml")
        try "name: wilma".write(to: jazzyConfig)

        try tmpDir.directoryURL.withCurrentDirectory {
            let system = System()
            try system.configure()
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertTrue(system.nameOpt.configured)
            XCTAssertEqual("barney", system.nameOpt.value)
        }
    }

    // 2c Config file - vs cli
    func testConfigFileCli() throws {
        let tmpDir = try TemporaryDirectory()
        let j2Config = try tmpDir.createFile(name: ".j2.yaml")
        try "name: barney".write(to: j2Config)

        try tmpDir.directoryURL.withCurrentDirectory {
            TestLogger.install()
            let system = System()
            try system.configure(cliOpts: "--name", "fred")
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertTrue(system.nameOpt.configured)
            XCTAssertEqual("fred", system.nameOpt.value)
            XCTAssertNotEqual([], TestLogger.shared.diagsBuf)
        }
    }

    // 3. version cmd (accurate)
    func testVersion() throws {
        TestLogger.install()
        TestLogger.shared.expectNoDiags = true
        let system = System()
        try system.configure(cliOpts: "--version", "--unreal")
        XCTAssertTrue(system.config.performConfigCommand())
        XCTAssertEqual([Version.j2libVersion], TestLogger.shared.messageBuf)
    }

    // 4. help cmds (something)
    func testHelp() throws {
        try ["--help", "--help-aliases"].forEach { helpCmd in
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let system = System()
            try system.configure(cliOpts: helpCmd)
            XCTAssertTrue(system.config.performConfigCommand())
            XCTAssertNotEqual([], TestLogger.shared.messageBuf)
            TestLogger.shared.messageBuf.forEach { msg in
                XCTAssertFalse(msg.contains("eyecatcher"))
            }
        }
    }

    // 5. quiet & debug update shared logger settings
    //    a. dbg prefix right shape
    //    b. debug beats quiet
    func testQuiet() throws {
        TestLogger.install()
        TestLogger.shared.expectNothing = true
        let system = System()
        try system.configure(cliOpts: "--quiet")
        XCTAssertFalse(system.config.performConfigCommand())
        XCTAssertEqual(Logger.quietLevels, TestLogger.shared.logger.activeLevels)
    }

    func testDebug() throws {
        TestLogger.install()
        let system = System()
        try system.configure(cliOpts: "--debug")
        XCTAssertFalse(system.config.performConfigCommand())
        XCTAssertEqual(Logger.allLevels, TestLogger.shared.logger.activeLevels)

        logDebug("d")
        logInfo("i")
        logWarning("w")
        logError("e")

        TestLogger.shared.diagsBuf.forEach { m in
            XCTAssertTrue(m.re_isMatch(#"\[\d\d:\d\d:\d\d ....\] .*$"#), m)
        }
        XCTAssertTrue(TestLogger.shared.messageBuf.isEmpty)
    }

    func testDebugVsQuiet() throws {
        TestLogger.install()
        let system = System()
        try system.configure(cliOpts: "--debug", "--quiet")
        XCTAssertFalse(system.config.performConfigCommand())
        XCTAssertEqual(Logger.allLevels, TestLogger.shared.logger.activeLevels)
        XCTAssertTrue(TestLogger.shared.messageBuf.isEmpty)
    }

    // 6. Opts error actually thrown
    func testOptsError() {
        let system = System()
        AssertThrows(try system.configure(cliOpts: "--bad"), OptionsError.self)
    }

    // SrcDir
    func testSrcDirConfigFile() throws {
        let tmpDir = try TemporaryDirectory()
        let configFile = tmpDir.directoryURL.appendingPathComponent(".j2.yaml")
        try "badOption: value".write(to: configFile)
        try TemporaryDirectory.withNew {
            let config = Config()
            let gather = Gather(config: config)
            try withExtendedLifetime(gather) {
                AssertThrows(try config.processOptions(cliOpts: ["--source-directory=\(tmpDir.directoryURL.path)"]),
                             OptionsError.self)
            }
        }
    }
}
