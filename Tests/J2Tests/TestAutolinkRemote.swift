//
//  TestAutolinkRemote.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

fileprivate struct System {
    let config: Config
    let format: Format

    var remote: FormatAutolinkRemote {
        format.autolink.autolinkRemote
    }

    init(cliArgs: [String] = [], yaml: String) throws {
        let tmpFile = FileManager.default.temporaryFileURL()
        try yaml.write(to: tmpFile)
        try self.init(cliArgs: cliArgs + ["--config", tmpFile.path])
    }

    init(cliArgs: [String] = []) throws {
        config = Config()
        format = Format(config: config)
        try config.processOptions(cliOpts: cliArgs)
    }

    func link(text: String) -> Autolink? {
        remote.autolink(hierarchicalName: text)
    }
}

class TestAutolinkRemote: XCTestCase {
    override func setUp() {
        initResources()
    }

    // MARK: base fetch gadget

    func testFetch() throws {
        let url = URL(string: "https://johnfairh.github.io/RubyGateway/badge.svg")!
        let data = try url.fetch()
        XCTAssertTrue(data.count > 500)

        let url2 = URL(string: "https://johnfairh.github.io/RubyGateway/bodge.svg")!
        AssertThrows(try url2.fetch(), .errUrlFetch)
    }

    func withBadURL(_ url: URL, and: () throws -> Void) rethrows {
        URL.harness.set(url, .failure(J2Error(.errUrlFetch)))
        defer { URL.harness.reset() }
        try and()
    }

    func withGoodURL(_ url: URL, _ string: String, and: () throws -> Void) rethrows {
        URL.harness.set(url, .success(string))
        defer { URL.harness.reset() }
        try and()
    }

    // MARK: config

    func testConfigErrors() throws {
        let missingURL = "remote_autolink:\n  - modules: Fred\n"
        AssertThrows(try System(yaml: missingURL), .errCfgRemoteUrl)

        let badURL = URL(string: "https://foo.com/bar")!
        try withBadURL(badURL.appendingPathComponent("site.json")) {
            let badURLYaml = "remote_autolink:\n  - url: \(badURL.absoluteString)\n"
            AssertThrows(try System(yaml: badURLYaml), .errCfgRemoteModules)
        }
    }

    func testConfigLocal() throws {
        let yaml = """
                   remote_autolink:
                     - url: https://foo.com/site
                       modules: ["M1", "M2"]
                   """
        let system = try System(yaml: yaml)
        XCTAssertEqual(1, system.remote.sources.count)
        XCTAssertEqual("https://foo.com/site", system.remote.sources[0].url.absoluteString)
        XCTAssertEqual(["M1", "M2"], system.remote.sources[0].modules)
    }

    func createSiteJSON(modules: [String]) throws -> String {
        let data = GenSiteRecord.Data(version: Version.j2libVersion, modules: modules)
        return try JSON.encode(data)
    }

    func testConfigRemote() throws {
        let url = URL(string: "https://foo.com/site")!
        let yaml = """
                   remote_autolink:
                     - url: \(url.absoluteString)
                   """

        try withGoodURL(url.appendingPathComponent("site.json"),
                        createSiteJSON(modules: ["ModA"])) {
            let system = try System(yaml: yaml)
            XCTAssertEqual(1, system.remote.sources.count)
            XCTAssertEqual(["ModA"], system.remote.sources[0].modules)
        }
    }
}
