//
//  TestAutolinkRemote.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

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
        remote.autolink(name: text)
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

    func withBadURL<T>(_ url: URL, and: () throws -> T) rethrows -> T{
        URL.harness.set(url, .failure(BBError(.errUrlFetch)))
        defer { URL.harness.reset() }
        return try and()
    }

    func withGoodURL<T>(_ url: URL, _ string: String, and: () throws -> T) rethrows -> T {
        URL.harness.set(url, .success(string))
        defer { URL.harness.reset() }
        return try and()
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
        XCTAssertEqual("https://foo.com/site/", system.remote.sources[0].url.absoluteString)
        XCTAssertEqual(["M1", "M2"], system.remote.sources[0].modules)
    }

    func createSiteJSON(modules: [String]) throws -> String {
        let data = GenSiteRecord.Data(version: Version.bebopLibVersion, modules: modules)
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

    // MARK: Index

    private func setUpSpmSwiftPackageSystem(fail: Bool = false) throws -> System {
        let url = URL(string: "https://foo.com/site")!
        let yaml = """
                   remote_autolink:
                      - url: \(url.absoluteString)
                        modules: SpmSwiftModule
                   """

        let searchJSONURL = fixturesURL.appendingPathComponent("SpmSwiftPackage/jazzy_docs/search.json")
        let searchJSON = try String(contentsOf: searchJSONURL)

        let action = { () -> System in
            let system = try System(yaml: yaml)
            system.remote.buildIndex()
            return system
        }

        let searchURL = url.appendingPathComponent("search.json")
        if fail {
            return try withBadURL(searchURL, and: action)
        } else {
            return try withGoodURL(searchURL, searchJSON, and: action)
        }
    }

    func testBuildIndex() throws {
        let system = try setUpSpmSwiftPackageSystem()

        guard let moduleIndex = system.remote.indiciesByModule["SpmSwiftModule"] else {
            XCTFail()
            return
        }
        XCTAssertEqual(76, moduleIndex.map.count)
    }

    func testFailedIndex() throws {
        TestLogger.install()
        let system = try setUpSpmSwiftPackageSystem(fail: true)
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
        XCTAssertTrue(system.remote.moduleIndices.isEmpty)
    }

    // MARK: Lookup

    func testIndexLookup() throws {
        let system = try setUpSpmSwiftPackageSystem()

        // simple by name
        guard let link1 = system.link(text: "ABaseClass") else {
            XCTFail()
            return
        }
        XCTAssertEqual("https://foo.com/site/types/abaseclass.html?swift", link1.markdownURL)

        // by module
        guard let link2 = system.link(text: "SpmSwiftModule.ABaseClass") else {
            XCTFail()
            return
        }
        XCTAssertEqual(link2.markdownURL, link1.markdownURL)

        // simple, nested
        guard let link3 = system.link(text: "ABaseClass.init(a:)") else {
            XCTFail()
            return
        }
        XCTAssertEqual("https://foo.com/site/types/abaseclass.html?swift#inita", link3.markdownURL)

        // abbreviated
        guard let link4 = system.link(text: "ABaseClass.init(...)") else {
            XCTFail()
            return
        }
        XCTAssertEqual(link3.markdownURL, link4.markdownURL)

        // failed
        XCTAssertNil(system.link(text: "BadIdentifier"))
    }
}
