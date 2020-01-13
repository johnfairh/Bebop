//
//  RubyTests.swift
//  J2Tests
//
//  Copyright 2019 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import RubyGateway
@testable import J2Lib

func tempFilePath() -> String {
    URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
}

// Check that the Ruby-jazzy-gem-wrapping stuff is working.

class RubyJazzyTests: XCTestCase {
    func testGem() throws {
        let jazzy = try RubyJazzy.create(scriptName: "J2Tests", cliArguments: ["--help"])

        let logPath = tempFilePath()
        let rbStdout = try Ruby.get("$stdout")
        try rbStdout.call("reopen", args: [logPath])
        do {
            try jazzy.run()
            XCTFail("Expected ruby SystemExit exception...")
        } catch {
            try rbStdout.call("flush")
            try rbStdout.call("reopen", args: [Ruby.get("STDOUT")])
        }

        let log = try String(contentsOf: URL(fileURLWithPath: logPath))
        XCTAssertTrue(log.hasPrefix("Usage: jazzy"))
    }
}
