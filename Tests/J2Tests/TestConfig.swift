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

    // 2. config file
    //    a. find locally and above, misc names
    //    b. clash between cli and cfg
    //    c. find from opt
    // 4. help cmd (something)
    // 5. quiet & debug update shared logger settings
    //    a. dbg prefix right shape

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

    // 3. version cmd (accurate)
    func testVersion() {
        Do {
            TestLogger.install()
            let system = System()
            try system.configure(cliOpts: "--version")
            XCTAssertTrue(system.config.performConfigCommand())
            XCTAssertEqual(Version.j2libVersion + "\n", TestLogger.shared.messageBuf)
        }
    }
}
