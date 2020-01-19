//
//  TestOptions.swift
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
        a = BoolOpt(s: "a", l: "aaa", help: "a help")
        b = StringOpt(s: "b", l: "bbb", help: "b help")
        c = EnumOpt(l: "color", help: "c help")
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
        AssertThrows(try apply(cliOpts), Error.options(""))
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

class TestOptions: XCTestCase {
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

    // LongOpts prefix completion
    func testLongOptsCompletion() throws {
        let system = System()
        try system.apply(["--col", "blue"])
        system.verify(Spec(false, false, false, nil, true, .blue))
    }

    // Auto-inverse
    func testAutoInverse() throws {
        let system = System()
        try system.apply(["--no-aaa"])
        system.verify(Spec(true, false, false, nil, false, nil))

        let opt = BoolOpt(l: "no-bananas", help: "bananas")
        try SimpleSystem(opt).parse(["--no-bananas"])
        XCTAssertTrue(opt.value)
        try SimpleSystem(opt).parse(["--bananas"])
        XCTAssertFalse(opt.value)

        let opt2 = BoolOpt(s: "b", y: "yaml_bananas", help: "bananas")
        try SimpleSystem(opt2).parse(["-b"])
        XCTAssertTrue(opt2.value)
    }

    // Lists
    func testLists() throws {
        let opt = StringListOpt(s: "s", l: "s", help: "help")
        try SimpleSystem(opt).parse("-s one -s two --s three".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three"])
    }

    // Enum lists
    func testEnumLists() throws {
        let opt = EnumListOpt<Color>(s: "e", l: "e", help: "help")
        try SimpleSystem(opt).parse("-e red -e red".components(separatedBy: " "))
        XCTAssertEqual(opt.value, [.red, .red])
    }

    // Inline lists
    func testInlineList() throws {
        let opt = StringListOpt(s: "s", l: "s", help: "help")
        try SimpleSystem(opt).parse("-s one,two -s three\\,four".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three,four"])
    }

    // Paths
    func testPath() throws {
        let opt = PathOpt(s: "p", l: "p", help: "path")
        try SimpleSystem(opt).parse(["-p", "foo/bar"])
        XCTAssertEqual(opt.value?.path, "\(FileManager.default.currentDirectoryPath)/foo/bar")

        let opt2 = PathListOpt(s: "p", l: "p", help: "path")
        try SimpleSystem(opt2).parse("--p /foo/bar,../foo/bar/baz".components(separatedBy: " "))
        XCTAssertEqual(opt2.value[0].path, "/foo/bar")
        XCTAssertTrue(opt2.value[1].path.hasSuffix("foo/bar/baz"))
        XCTAssertTrue(!opt2.value[1].path.contains(".."))
    }

    // Path validation 1
    func testPathValidations() throws {
        let opt = PathOpt(s: "p", y: "p", help: "path")
        let ss = SimpleSystem(opt)
        try ss.parse(["-p", "\(#file)"])
        try opt.checkIsFile()
        AssertThrows(try opt.checkIsDirectory(), Error.options(""))

        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        try ss.parse(["-p", "\(directory.path)"])
        try opt.checkIsDirectory()
        AssertThrows(try opt.checkIsFile(), Error.options(""))

        try ss.parse(["-p", "blargle"])
        AssertThrows(try opt.checkIsFile(), Error.options(""))
    }

    // Path validation 2
    func testPathListValidations() throws {
        let opt = PathListOpt(s: "p", y: "p", help: "path")
        let ss = SimpleSystem(opt)
        try ss.parse(["-p", "\(#file)", "-p", "\(#file)"])
        try opt.checkAreFiles()
        AssertThrows(try opt.checkAreDirectories(), Error.options(""))
    }

    // Globs
    func testGlob() {
        let opt = GlobOpt(s: "g", l: "g", help: "glob")
        XCTAssertNoThrow(try SimpleSystem(opt).parse(["--g", "foo*/bar"]))
        XCTAssertEqual(opt.value?.value, "\(FileManager.default.currentDirectoryPath)/foo*/bar")

        let opt2 = GlobListOpt(s: "g", l: "g", help: "glob")
        XCTAssertNoThrow(try SimpleSystem(opt2).parse("--g /*/bar,../foo/*/baz".components(separatedBy: " ")))
        XCTAssertEqual(opt2.value[0], "/*/bar")
        XCTAssertTrue(opt2.value[1].value.hasSuffix("foo/*/baz"))
        XCTAssertTrue(!opt2.value[1].value.contains(".."))
    }

    // Syntax errors
    // (hmm this isn't testing we get the *right* errors)
    func testSyntaxErrors() throws {
        let system = System()

        try system.applyOptionsError(["hello"])

        try system.applyOptionsError(["--hello"])
        try system.applyOptionsError(["-h"])

        try system.applyOptionsError("-b one --bbb two".components(separatedBy: " "))

        try system.applyOptionsError("--aaa --no-aaa".components(separatedBy: " "))

        try system.applyOptionsError("--no-bbb foo".components(separatedBy: " "))

        try system.applyOptionsError(["--color"])
    }

    // Validation errors
    func testEnumValidation() throws {
        let system = System()
        try system.applyOptionsError(["--color", "pink"])
    }
}
