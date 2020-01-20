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

struct Client {
    let a: BoolOpt
    let b: StringOpt
    let c: EnumOpt<Color>

    init(optsParser: OptsParser) {
        a = BoolOpt(s: "a", l: "aaa", y: "aaa", help: "a help")
        b = StringOpt(s: "b", l: "bbb", y: "bbb", help: "b help")
        c = EnumOpt(l: "color", y: "ccc", help: "c help")
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
    /// No args, simple args
    func testBasic() {
        Do {
            let system = System()
            try system.apply([])
            system.verify(Spec(false, false, false, nil, false, nil))
            try system.apply(["-a", "--bbb", "fred", "--color", "red"])
            system.verify(Spec(true, true, true, "fred", true, .red))
        }
    }

    // Default values
    func testDefaults() {
        Do {
            let system = System()
            system.client.a.def(true)
            system.client.b.def("Default")
            system.client.c.def(.blue)
            try system.apply([])
            system.verify(Spec(false, true, false, "Default", false, .blue))
        }
    }

    // LongOpts prefix completion
    func testLongOptsCompletion() {
        Do {
            let system = System()
            try system.apply(["--col", "blue"])
            system.verify(Spec(false, false, false, nil, true, .blue))
        }
    }

    // Auto-inverse
    func testAutoInverse() {
        Do {
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
    }

    // Lists
    func testLists() {
        Do {
            let opt = StringListOpt(s: "s", l: "s", help: "help")
            try SimpleSystem(opt).parse("-s one -s two --s three".components(separatedBy: " "))
            XCTAssertEqual(opt.value, ["one", "two", "three"])
        }
    }

    // Enum lists
    func testEnumLists() {
        Do {
            let opt = EnumListOpt<Color>(s: "e", l: "e", help: "help")
            try SimpleSystem(opt).parse("-e red -e red".components(separatedBy: " "))
            XCTAssertEqual(opt.value, [.red, .red])
        }
    }

    // Inline lists
    func testInlineList() {
        Do {
            let opt = StringListOpt(s: "s", l: "s", help: "help")
            try SimpleSystem(opt).parse("-s one,two -s three\\,four".components(separatedBy: " "))
            XCTAssertEqual(opt.value, ["one", "two", "three,four"])
        }
    }

    // Paths
    func testPath() {
        Do {
            let opt = PathOpt(s: "p", l: "p", help: "path")
            try SimpleSystem(opt).parse(["-p", "foo/bar"])
            XCTAssertEqual(opt.value?.path, "\(FileManager.default.currentDirectoryPath)/foo/bar")

            let opt2 = PathListOpt(s: "p", l: "p", help: "path")
            try SimpleSystem(opt2).parse("--p /foo/bar,../foo/bar/baz".components(separatedBy: " "))
            XCTAssertEqual(opt2.value[0].path, "/foo/bar")
            XCTAssertTrue(opt2.value[1].path.hasSuffix("foo/bar/baz"))
            XCTAssertTrue(!opt2.value[1].path.contains(".."))
        }
    }

    // Path validation 1
    func testPathValidations() {
        Do {
            let opt = PathOpt(s: "p", y: "p", help: "path")
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
    }

    func testPathDefault() {
        Do {
            let opt = PathOpt(s: "p", y: "p", help: "path").def("defaultPath")
            let ss = SimpleSystem(opt)
            try ss.parse([])
            XCTAssertFalse(opt.configured)
            XCTAssertEqual(FileManager.default.currentDirectoryPath + "/defaultPath", opt.value?.path)
        }
    }

    // Path validation 2
    func testPathListValidations() {
        Do {
            let opt = PathListOpt(s: "p", y: "p", help: "path")
            let ss = SimpleSystem(opt)
            try ss.parse(["-p", "\(#file)", "-p", "\(#file)"])
            try opt.checkAreFiles()
            AssertThrows(try opt.checkAreDirectories(), OptionsError.self)
        }
    }

    // Globs
    func testGlob() {
        Do {
            let opt = GlobOpt(s: "g", l: "g", help: "glob")
            try SimpleSystem(opt).parse(["--g", "foo*/bar"])
            XCTAssertEqual(opt.value?.value, "\(FileManager.default.currentDirectoryPath)/foo*/bar")

            let opt2 = GlobListOpt(s: "g", l: "g", help: "glob")
            try SimpleSystem(opt2).parse("--g /*/bar,../foo/*/baz".components(separatedBy: " "))
            XCTAssertEqual(opt2.value[0], "/*/bar")
            XCTAssertTrue(opt2.value[1].value.hasSuffix("foo/*/baz"))
            XCTAssertTrue(!opt2.value[1].value.contains(".."))
        }
    }

    // Syntax errors
    // (hmm this isn't testing we get the *right* errors)
    func testSyntaxErrors() {
        Do {
            let system = System()

            try system.applyOptionsError(["hello"])

            try system.applyOptionsError(["--hello"])
            try system.applyOptionsError(["-h"])

            try system.applyOptionsError("-b one --bbb two".components(separatedBy: " "))

            try system.applyOptionsError("--aaa --no-aaa".components(separatedBy: " "))

            try system.applyOptionsError("--no-bbb foo".components(separatedBy: " "))

            try system.applyOptionsError(["--color"])
        }
    }

    // Validation errors
    func testEnumValidation() {
        Do {
            let system = System()
            try system.applyOptionsError(["--color", "pink"])
        }
    }

    // Basic yaml function
    func testYamlBasic() {
        Do {
            let system = System()
            try system.apply("""
                             aaa: true
                             bbb:
                               - Fish
                             ccc: red
                             """)
            system.verify(Spec(true, true, true, "Fish", true, .red))
        }
    }

    // Actual lists
    func testYamlSequence() {
        Do {
            let opt = StringListOpt(y: "yamlonly", help: "")
            let ss = SimpleSystem(opt)
            try ss.parse(yaml: """
                         yamlonly:
                           - one
                           - two
                           - three
                         """)
            XCTAssertEqual(opt.value, ["one", "two", "three"])
        }
    }

    // Yaml option
    func testYamlOpt() {
        Do {
            let opt = YamlOpt(y: "custom_categories", help: "")
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
        }
    }

    // Yaml vs. CLI
    func testYamlVsCli() {
        Do {
            let opt = StringOpt(s: "c", y: "ccc", help: "")
            let system = SimpleSystem(opt)
            try system.parse(["-c", "foo"], yaml: "ccc: bar")
            XCTAssertEqual(opt.value, "foo")
        }
    }

    // Yaml errors
    func testYamlErrors() {

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

        Do {
            try badYamls.forEach { yaml in
                AssertThrows(try system.apply(yaml), OptionsError.self, "Yaml should be bad: \(yaml)")
            }
        }
    }
}
