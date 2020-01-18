//
//  OptionsTests.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib

enum Color: String, CaseIterable {
    case red
    case blue
}

struct Client {
    let a: BoolOpt
    let b: StringOpt
    let c: EnumOpt<Color>

    init(optsParser: OptsParser) {
        a = BoolOpt(s: "-a", l: "--aaa", help: "a help")
        b = StringOpt(s: "-b", l: "--bbb", help: "b help")
        c = EnumOpt(l: "--color", help: "c help")
        optsParser.addOpts(from: self)
    }
}

struct Spec {
    let aSet: Bool
    let aValue: Bool
    let bSet: Bool
    let bValue: String?
    let cSet: Bool
    let cValue: Color?

    init(_ aSet: Bool, _ aValue: Bool, _ bSet: Bool, _ bValue: String?,
         _ cSet: Bool, _ cValue: Color?) {
        self.aSet = aSet
        self.aValue = aValue
        self.bSet = bSet
        self.bValue = bValue
        self.cSet = cSet
        self.cValue = cValue
    }
}

final class System {
    var optsParser: OptsParser!
    var client: Client!

    init() {
        reset()
    }

    func reset() {
        optsParser = OptsParser()
        client = Client(optsParser: optsParser)
    }

    func apply(_ cliOpts: [String]) throws {
        try optsParser.apply(cliOpts: cliOpts)
    }

    func applyOptionsError(_ cliOpts: [String]) throws {
        reset()
        do {
            try apply(cliOpts)
            XCTFail("Ought to have thrown")
        } catch Error.options(let msg) {
            print(msg)
        }
    }

    func verify(_ spec: Spec) {
        XCTAssertEqual(spec.aSet, client.a.configured)
        XCTAssertEqual(spec.aValue, client.a.value)
        XCTAssertEqual(spec.bSet, client.b.configured)
        XCTAssertEqual(spec.bValue, client.b.value)
        XCTAssertEqual(spec.cSet, client.c.configured)
        XCTAssertEqual(spec.cValue, client.c.value)
    }
}

final class SimpleSystem {
    var opt: Opt

    init(_ opt: Opt) { self.opt = opt }

    func parse(_ cliOpts: [String]) throws {
        let optsParser = OptsParser()
        optsParser.addOpts(from: self)
        try optsParser.apply(cliOpts: cliOpts)
    }
}

class OptionsTests: XCTestCase {
    /// No args, simple args
    func testBasic() throws {
        let system = System()
        try system.apply([])
        system.verify(Spec(false, false, false, nil, false, nil))
        try system.apply(["-a", "--bbb", "fred", "--color", "red"])
        system.verify(Spec(true, true, true, "fred", true, .red))
    }

    // Default values
    func testDefaults() throws {
        let system = System()
        system.client.a.def(true)
        system.client.b.def("Default")
        system.client.c.def(.blue)
        try system.apply([])
        system.verify(Spec(false, true, false, "Default", false, .blue))
    }

    // Lists
    func testLists() throws {
        let opt = StringListOpt(s: "-s", l: "--s", help: "help")
        try SimpleSystem(opt).parse("-s one -s two --s three".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three"])
    }

    // Enum lists
    func testEnumLists() throws {
        let opt = EnumListOpt<Color>(s: "-e", l: "--e", help: "help")
        try SimpleSystem(opt).parse("-e red -e red".components(separatedBy: " "))
        XCTAssertEqual(opt.value, [.red, .red])
    }

    // Inline lists
    func NO_testInlineList() throws {
        let opt = StringListOpt(s: "-s", l: "--s", help: "help")
        try SimpleSystem(opt).parse("-s one,two -s three\\,four".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three\\,four"])
    }

    // Paths
    func NO_testPath() throws {
        let opt = PathOpt(s: "-p", l: "--p", help: "path")
        try SimpleSystem(opt).parse(["-p", "foo/bar"])
        XCTAssertEqual(opt.value, "\(FileManager.default.currentDirectoryPath)/foo/bar")

        let opt2 = PathListOpt(s: "-p", l: "--p", help: "path")
        try SimpleSystem(opt2).parse("--p /foo/bar,../foo/bar/baz".components(separatedBy: " "))
        XCTAssertEqual(opt2.value[0], "/foo/bar")
        XCTAssertTrue(opt2.value[1].hasSuffix("foo/bar/baz"))
        XCTAssertTrue(!opt2.value[1].contains(".."))
    }

    // Globs
    func NO_testGlob() throws {
        let opt = GlobOpt(s: "-g", l: "--g", help: "glob")
        try SimpleSystem(opt).parse(["--g", "foo*/bar"])
        XCTAssertEqual(opt.value, "\(FileManager.default.currentDirectoryPath)/foo*/bar")

        let opt2 = GlobListOpt(s: "-g", l: "--g", help: "glob")
        try SimpleSystem(opt2).parse("--p /*/bar,../foo/*/baz".components(separatedBy: " "))
        XCTAssertEqual(opt2.value[0], "/*/bar")
        XCTAssertTrue(opt2.value[1].hasSuffix("foo/*/baz"))
        XCTAssertTrue(!opt2.value[1].contains(".."))
    }

    // Syntax errors
    // (hmm this isn't testing we get the *right* errors)
    func testSyntaxErrors() throws {
        let system = System()

        try system.applyOptionsError(["hello"])

        try system.applyOptionsError(["--hello"])

        try system.applyOptionsError("-b one --bbb two".components(separatedBy: " "))

        try system.applyOptionsError(["--color"])
    }

    // Validation errors
    func testEnumValidation() throws {
        let system = System()
        try system.applyOptionsError(["--color", "pink"])
    }
}
