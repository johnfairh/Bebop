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
    let nameOpt = StringOpt(l: "name", y: "name", help: "n")
    var checkOptionsCalled = false

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
    }

    // 1. register, propagates CLI opts and calls checkOpts
    func testBasic() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNothing = true

            let system = System()
            try system.configure()

            XCTAssertTrue(system.checkOptionsCalled)
            XCTAssertFalse(system.nameOpt.configured)

            XCTAssertFalse(system.config.performConfigCommand())
        }
    }

    // 2a Config file - explicit and cwd
    func testConfigFile() {
        Do {
            let tmpDir = try TemporaryDirectory()
            let configFile = try tmpDir.createFile(name: ".j2.yaml")
            try "name: fred".write(to: configFile, atomically: true, encoding: .utf8)

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
    }

    // 2b Config file - Check j2->jazzy and parent-searching
    func testConfigFileSearch() {
        Do {
            let tmpDir = try TemporaryDirectory()
            let tmpSubDir = try tmpDir.createDirectory()
            let j2Config = try tmpDir.createFile(name: ".j2.yaml")
            try "name: barney".write(to: j2Config, atomically: true, encoding: .utf8)
            let jazzyConfig = try tmpSubDir.createFile(name: ".jazzy.yaml")
            try "name: wilma".write(to: jazzyConfig, atomically: true, encoding: .utf8)

            try tmpDir.directoryURL.withCurrentDirectory {
                let system = System()
                try system.configure()
                XCTAssertFalse(system.config.performConfigCommand())
                XCTAssertTrue(system.nameOpt.configured)
                XCTAssertEqual("barney", system.nameOpt.value)
            }
        }
    }

    // 2c Config file - vs cli
    func testConfigFileCli() {
        Do {
            let tmpDir = try TemporaryDirectory()
            let j2Config = try tmpDir.createFile(name: ".j2.yaml")
            try "name: barney".write(to: j2Config, atomically: true, encoding: .utf8)

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
    }


    // 3. version cmd (accurate)
    func testVersion() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let system = System()
            try system.configure(cliOpts: "--version")
            XCTAssertTrue(system.config.performConfigCommand())
            XCTAssertEqual([Version.j2libVersion], TestLogger.shared.messageBuf)
        }
    }

    // 4. help cmd (something)
    func FAIL_testHelp() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let system = System()
            try system.configure(cliOpts: "--help")
            XCTAssertTrue(system.config.performConfigCommand())
            XCTAssertNotEqual([], TestLogger.shared.messageBuf)
        }
    }

    // 5. quiet & debug update shared logger settings
    //    a. dbg prefix right shape
    func testQuiet() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNothing = true
            let system = System()
            try system.configure(cliOpts: "--quiet")
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertEqual(Logger.quietLevels, TestLogger.shared.logger.activeLevels)
        }
    }

    func testDebug() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let system = System()
            try system.configure(cliOpts: "--debug")
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertEqual(Logger.allLevels, TestLogger.shared.logger.activeLevels)

            logDebug("d")
            logInfo("i")
            logWarning("w")
            logError("e")

            TestLogger.shared.messageBuf.forEach { m in
                XCTAssertTrue(m.re_isMatch(#"\[\d\d:\d\d:\d\d ....\] .*$"#))
            }
        }
    }

    func testDebugVsQuiet() {
        Do {
            TestLogger.install()
            TestLogger.shared.expectNoDiags = true
            let system = System()
            try system.configure(cliOpts: "--debug", "--quiet")
            XCTAssertFalse(system.config.performConfigCommand())
            XCTAssertEqual(Logger.allLevels, TestLogger.shared.logger.activeLevels)
        }
    }
}