//
//  TestOptions.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
import Yams
@testable import J2Lib

enum Color: String, CaseIterable {
    case red
    case blue
}

fileprivate struct Client {
    let a: BoolOpt
    let b: StringOpt
    let c: EnumOpt<Color>

    init(optsParser: OptsParser) {
        a = BoolOpt(s: "a", l: "aaa")
        b = StringOpt(s: "b", l: "bbb").help("BBB")
        c = EnumOpt(l: "color")
        optsParser.addOpts(from: self)
    }
}

fileprivate struct Spec {
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

fileprivate final class System {
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

    func apply(_ yaml: String) throws {
        try optsParser.apply(yaml: yaml)
    }

    func applyOptionsError(_ cliOpts: [String]) throws {
        reset()
        AssertThrows(try apply(cliOpts), OptionsError.self)
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

    func parse(_ cliOpts: [String] = [], yaml: String? = nil) throws {
        let optsParser = OptsParser()
        optsParser.addOpts(from: self)
        if !cliOpts.isEmpty {
            try optsParser.apply(cliOpts: cliOpts)
        }
        if let yaml = yaml {
            try optsParser.apply(yaml: yaml)
        }
    }
}

class TestOptions: XCTestCase {

    override class func setUp() {
        TestLogger.uninstall()
    }

    override func setUp() {
        initResources()
    }

    /// No args, simple args
    func testBasic() throws {
        let system = System()
        try system.apply([])
        system.verify(Spec(false, false, false, nil, false, nil))
        try system.apply(["-a", "--bbb", "fred", "--color", "red"])
        system.verify(Spec(true, true, true, "fred", true, .red))
        system.reset()
        try system.apply(["-a", "--bbb=fr=d", "--color=red"])
        system.verify(Spec(true, true, true, "fr=d", true, .red))
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

        let opt = BoolOpt(l: "no-bananas")
        try SimpleSystem(opt).parse(["--no-bananas"])
        XCTAssertTrue(opt.value)
        try SimpleSystem(opt).parse(["--bananas"])
        XCTAssertFalse(opt.value)

        let opt2 = BoolOpt(s: "b", l: "bbb")
        try SimpleSystem(opt2).parse(["-b"])
        XCTAssertTrue(opt2.value)
    }

    // Help
    func testHelp() {
        let system = System()
        XCTAssertEqual("red|blue", system.client.c.helpParam)
        XCTAssertEqual("BBB", system.client.b.helpParam)
        XCTAssertEqual("--[no-]aaa|-a", system.client.a.name(usage: true))
    }

    // Lists
    func testLists() throws {
        let opt = StringListOpt(s: "s", l: "s")
        try SimpleSystem(opt).parse("-s one -s two --s three".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three"])
    }

    // Enum lists
    func testEnumLists() throws {
        let opt = EnumListOpt<Color>(s: "e", l: "e")
        try SimpleSystem(opt).parse("-e red -e red".components(separatedBy: " "))
        XCTAssertEqual(opt.value, [.red, .red])
        XCTAssertEqual("red|blue,...", opt.helpParam)
    }

    // Inline lists
    func testInlineList() throws {
        let opt = StringListOpt(s: "s", l: "s")
        try SimpleSystem(opt).parse("-s one,two -s three\\,four".components(separatedBy: " "))
        XCTAssertEqual(opt.value, ["one", "two", "three,four"])
    }

    // Paths
    func testPath() throws {
        let opt = PathOpt(s: "p", l: "p")
        try SimpleSystem(opt).parse(["-p", "foo/bar"])
        XCTAssertEqual(opt.value?.path, "\(FileManager.default.currentDirectoryPath)/foo/bar")

        let opt2 = PathListOpt(s: "p", l: "p")
        try SimpleSystem(opt2).parse("--p /foo/bar,../foo/bar/baz".components(separatedBy: " "))
        XCTAssertEqual(opt2.value[0].path, "/foo/bar")
        XCTAssertTrue(opt2.value[1].path.hasSuffix("foo/bar/baz"))
        XCTAssertTrue(!opt2.value[1].path.contains(".."))
    }

    // Path validation 1
    func testPathValidations() throws {
        let opt = PathOpt(s: "p", l: "ppp")
        let ss = SimpleSystem(opt)
        try ss.parse(["-p", "\(#file)"])
        try opt.checkIsFile()
        AssertThrows(try opt.checkIsDirectory(), OptionsError.self)

        let directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        try ss.parse(["-p", "\(directory.path)"])
        try opt.checkIsDirectory()
        AssertThrows(try opt.checkIsFile(), OptionsError.self)

        try ss.parse(["-p", "blargle"])
        AssertThrows(try opt.checkIsFile(), OptionsError.self)
    }

    func testPathDefault() throws {
        let opt = PathOpt(s: "p", l: "ppp").def("defaultPath")
        let ss = SimpleSystem(opt)
        try ss.parse([])
        XCTAssertFalse(opt.configured)
        XCTAssertEqual(FileManager.default.currentDirectoryPath + "/defaultPath", opt.value?.path)
    }

    // Path validation 2
    func testPathListValidations() throws {
        let opt = PathListOpt(s: "p", l: "ppp")
        let ss = SimpleSystem(opt)
        try ss.parse(["-p", "\(#file)", "-p", "\(#file)"])
        try opt.checkAreFiles()
        AssertThrows(try opt.checkAreDirectories(), OptionsError.self)
    }

    // Globs
    func testGlob() throws {
        let opt = GlobOpt(s: "g", l: "g")
        try SimpleSystem(opt).parse(["--g", "foo*/bar"])
        XCTAssertEqual(opt.value?.value, "\(FileManager.default.currentDirectoryPath)/foo*/bar")

        let opt2 = GlobListOpt(s: "g", l: "g")
        try SimpleSystem(opt2).parse("--g /*/bar,../foo/*/baz".components(separatedBy: " "))
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

        try system.applyOptionsError(["--aaa=true"])
    }

    // Validation errors
    func testEnumValidation() throws {
        let system = System()
        try system.applyOptionsError(["--color", "pink"])
    }

    // Basic yaml function
    func testYamlBasic() throws {
        let system = System()
        try system.apply("""
                         aaa: true
                         bbb:
                           - Fish
                         color: red
                         """)
        system.verify(Spec(true, true, true, "Fish", true, .red))
    }

    // Sanity-check that we can read json too...
    func testJsonBasic() throws {
        let system = System()
        try system.apply("""
                         {
                           "aaa": "true",
                           "bbb": [ "Fish" ],
                           "color": "red"
                         }
                         """)
        system.verify(Spec(true, true, true, "Fish", true, .red))
    }

    // Actual lists
    func testYamlSequence() throws {
        let opt = StringListOpt(y: "yamlonly")
        let ss = SimpleSystem(opt)
        try ss.parse(yaml: """
                     yamlonly:
                       - one
                       - two
                       - three
                     """)
        XCTAssertEqual(opt.value, ["one", "two", "three"])
    }

    // Yaml option
    func testYamlOpt() throws {
        let opt = YamlOpt(y: "custom_categories")
        let ss = SimpleSystem(opt)
        try ss.parse(yaml: """
                     custom_categories:
                        - name: Foo
                          children:
                            - Bar
                     """)
        XCTAssertTrue(opt.configured)
        let actual = try Yams.serialize(node: opt.configValue!)
        XCTAssertEqual("""
                       - name: Foo
                         children:
                         - Bar

                       """, actual)
        XCTAssertEqual("custom_categories", opt.name(usage: false))
        XCTAssertTrue(opt.name(usage: true).hasPrefix("custom_categories ("))
    }

    // Yaml vs. CLI
    func testYamlVsCli() throws {
        let opt = StringOpt(s: "c", l: "ccc")
        let system = SimpleSystem(opt)
        try system.parse(["-c", "foo"], yaml: "ccc: bar")
        XCTAssertEqual(opt.value, "foo")
    }

    // Yaml errors
    func testYamlErrors() throws {

        let badYamls = [
            "", // not yaml
            "scalar", // not a mapping
            "[1] : value", // mapping with a weird key
            "notAKey: true", // unexpected key
            """
            bbb:
              key: value
            """, // value is a mapping
            "aaa: fish", // undecodable bool
            """
            bbb:
              - key: value
            """, // thing in sequence isn't scalar
            """
            bbb:
             - one
             - two
            """, // non-singular sequence
        ]

        let system = System()

        try badYamls.forEach { yaml in
            AssertThrows(try system.apply(yaml), OptionsError.self, "Yaml should be bad: \(yaml)")
        }
    }

    // Misc option ui
    func testInvertableSyntax() {
        let opt1 = BoolOpt(l: "foo")
        XCTAssertTrue(opt1.isInvertable)
        XCTAssertTrue(opt1.name(usage: false).contains("--[no-]foo"))

        let opt2 = BoolOpt(l: "no-foo")
        XCTAssertTrue(opt2.isInvertable)
        XCTAssertTrue(opt2.name(usage: true).contains("--[no-]foo"))
    }

    // More misc option ui
    func testSortKey() {
        let opt1 = BoolOpt(l: "aaa")
        let opt2 = BoolOpt(y: "bbb")

        XCTAssertEqual("aaa", opt1.sortKey)
        XCTAssertEqual("bbb", opt2.sortKey)
    }

    // Alias options
    func testAlias() throws {
        struct Aliased {
            let realOpt: BoolOpt
            let aliasOpt: AliasOpt

            init() {
                realOpt = BoolOpt(l: "rrr")
                aliasOpt = AliasOpt(realOpt: realOpt, s: "a", l: "aaa")
            }
        }
        let component = Aliased()
        let optsParser = OptsParser()
        optsParser.addOpts(from: component)
        try optsParser.apply(cliOpts: ["--aa"]) // prefix match
        XCTAssertTrue(component.realOpt.configured)
        XCTAssertTrue(component.realOpt.value)
    }
}
