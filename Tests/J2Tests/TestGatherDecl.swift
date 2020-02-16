//
//  TestGatherDecl.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import SourceKittenFramework

// Declaration parsing

extension SwiftDeclarationBuilder {
    convenience init(dict: SourceKittenDict, file: File? = nil, kind: DefKind? = nil) {
        self.init(dict: dict, file: file, kind: kind, availabilityRules: GatherAvailabilityRules())
    }
}

class TestGatherDecl: XCTestCase {
    override func setUp() {
        initResources()
    }

    // Annotated XML parse
    private func fullyAnnotatedToString(_ xml: String) -> String? {
        // doesn't matter what outer element is, just that it's there
        let realXML = "<decl.function.method.instance>\(xml)</decl.function.method.instance>"
        let dict = ["key.fully_annotated_decl" : realXML]
        let builder = SwiftDeclarationBuilder(dict: dict)
        let _ = builder.build()
        return builder.compilerDecl
    }

    // Simple XML parse
    func testBasicDecls() {
        XCTAssertEqual("passthrough", fullyAnnotatedToString("passthrough"))
        XCTAssertEqual("passthrough", fullyAnnotatedToString("<tag>passthrough</tag>"))
        XCTAssertEqual("public class Fred", fullyAnnotatedToString("<syntaxtype.keyword>public</syntaxtype.keyword> <syntaxtype.keyword>class</syntaxtype.keyword> <decl.name>Fred</decl.name>"))
    }

    // Attribute stripping
    func testAttributesXmlStripping() {
        XCTAssertEqual("Fred", fullyAnnotatedToString("<syntaxtype.attribute.builtin><syntaxtype.attribute.name>@objc</syntaxtype.attribute.name></syntaxtype.attribute.builtin> <decl.name>Fred</decl.name>"))
    }

    // Errors
    func testAnnotatedErrors() {
        TestLogger.install()
        TestLogger.shared.logger.activeLevels = Logger.allLevels
        XCTAssertNil(SwiftDeclarationBuilder(dict: [:]).build())

        let badDict = ["key.fully_annotated_decl" : "<open text"]
        XCTAssertNil(SwiftDeclarationBuilder(dict: badDict).build())
        XCTAssertEqual(2, TestLogger.shared.diagsBuf.count)
    }

    // 'orrible parsed text regular expressions
    func testParsedDecl() {
        let b = SwiftDeclarationBuilder(dict: [:])
        let str1 = "foo(bar)"
        XCTAssertEqual(str1, b.parse(parsedDecl: str1))
        let str2 = "@discardableResult foo(bar)"
        XCTAssertEqual("foo(bar)", b.parse(parsedDecl: str2))
        let str3 = #"@available(nonsense, "quoted nonsense") foo(bar)"#
        XCTAssertEqual("foo(bar)", b.parse(parsedDecl: str3))
        let str4 = """
                   @aaaaa foo(bar,
                              baz)
                   """
        XCTAssertEqual("""
                       foo(bar,
                           baz)
                       """, b.parse(parsedDecl: str4))
    }

    // Parse preference
    func testParsePreference() {
        let classKind = DefKind.from(key: SwiftDeclarationKind.class.rawValue)
        let dict = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                    "key.parsed_declaration" : "One\nTwo"]
        let builder = SwiftDeclarationBuilder(dict: dict, kind: classKind)
        let decl = builder.build()
        XCTAssertEqual("One\nTwo", decl?.declaration)

        let dict2 = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                     "key.parsed_declaration" : "One Two"]
        let builder2 = SwiftDeclarationBuilder(dict: dict2, kind: classKind)
        let decl2 = builder2.build()
        XCTAssertEqual("Inner", decl2?.declaration)

        let extKind = DefKind.from(key: SwiftDeclarationKind.extension.rawValue)
        let extDict = ["key.fully_annotated_decl" : "<outer>class Fred</outer>",
                       "key.parsed_declaration" : "extension Fred"]
        let extBuilder = SwiftDeclarationBuilder(dict: extDict, kind: extKind)
        let extDecl = extBuilder.build()
        XCTAssertEqual("extension Fred", extDecl?.declaration)

        let varKind = DefKind.from(key: SwiftDeclarationKind.varClass.rawValue)
        let varDict = ["key.fully_annotated_decl" : "<outer>var toast { get set }</outer>",
                       "key.parsed_declaration" : "var toast = { blah\n }()"]
        let varBuilder = SwiftDeclarationBuilder(dict: varDict, kind: varKind)
        let varDecl = varBuilder.build()
        XCTAssertEqual("var toast { get set }", varDecl?.declaration)
    }

    // Attributes
    func testAttributes() {
        let file = File(contents: "@discardableResult public func fred() {}")

        let attrDicts: [SourceKittenDict] =
            [["key.attribute" : "source.decl.attribute.public",
              "key.length" : Int64(6),
              "key.offset" : Int64(19)],
             ["key.attribute" : "source.decl.attribute.public",
              "key.offset" : Int64(89)],
             ["key.attribute" : "source.decl.attribute.discardableResult",
              "key.length" : Int64(18),
              "key.offset" : Int64(0)]]
        let dict: SourceKittenDict =
            ["key.attributes" : attrDicts,
             "key.fully_annotated_decl": "<outer>public func fred()</outer>"]
        let builder = SwiftDeclarationBuilder(dict: dict, file: file)
        
        let parsed = builder.parse(attributeDicts: attrDicts)
        XCTAssertEqual(["@discardableResult"], parsed)

        guard let built = builder.build() else {
            XCTFail("Couldn't build decl-info")
            return
        }
        XCTAssertEqual("@discardableResult\npublic func fred()", built.declaration)
    }

    private func checkAvailabilityControl(_ availabilityRules: GatherAvailabilityRules, _ expect: [String], line: UInt = #line) {
        let file = File(contents: "@available(iOS, introduced: 1) func fred() {}")

        let attrDicts: [SourceKittenDict] = [
            ["key.attribute" : "source.decl.attribute.available",
             "key.length": Int64(30),
             "key.offset": Int64(0)]]
        let dict: SourceKittenDict = [
            "key.attributes": attrDicts,
            "key.fully_annotated_decl": "<outer>func fred()</outer>"]
        let builder = SwiftDeclarationBuilder(dict: dict, file: file, kind: nil, availabilityRules: availabilityRules)
        guard let built = builder.build() else {
            XCTFail("Couldn't build decl-info", line: line)
            return
        }
        XCTAssertEqual(expect, built.availability)
    }

    func testAvailabilityControl() {
        checkAvailabilityControl(GatherAvailabilityRules(), ["iOS 1+"])
        checkAvailabilityControl(GatherAvailabilityRules(defaults: [], ignoreAttr: true), [])
        checkAvailabilityControl(GatherAvailabilityRules(defaults: ["Def"], ignoreAttr: false), ["Def", "iOS 1+"])
        checkAvailabilityControl(GatherAvailabilityRules(defaults: ["Def"], ignoreAttr: true), ["Def"])
        checkAvailabilityControl(GatherAvailabilityRules(defaults: ["Def1", "Def2"], ignoreAttr: true), ["Def1", "Def2"])
    }

    // Available empire.  or at least a satrapie.
    private func checkAvail(_ available: String, _ expectAvail: [String], _ expectDeprecations: [String],
                            file: StaticString = #file, line: UInt = #line) {
        let builder = SwiftDeclarationBuilder(dict: [:])
        builder.parse(availables: [available])
        XCTAssertEqual(expectAvail, builder.availability, file: file, line: line)

        let deprecation: [String]
        if builder.deprecations.count > 0 {
            deprecation = [(builder.deprecations[0])["en"]!]
        } else {
            deprecation = []
        }

        XCTAssertEqual(expectDeprecations, deprecation, file: file, line: line)
    }

    func testAvailable() {
        checkAvail("@available(swift 5, *)", ["swift 5+"], [])
        checkAvail("@available (iOS 13,macOS 12 ,*)", ["iOS 13+", "macOS 12+"], [])
        checkAvail("@available(*, unavailable)", [], ["Unavailable."])
        checkAvail("@available(*, unavailable, message: \"MSG\" )", [], ["Unavailable. MSG."])
        checkAvail("@available(*, unavailable, message: \"MSG\", renamed: \"NU\" )",
                   [], ["Unavailable. MSG. Renamed: `NU`."])
        checkAvail("@available(*, deprecated, renamed: \"NU\" )",
                   [], ["Deprecated. Renamed: `NU`."])
        checkAvail("@available(iOS, introduced: 1)", ["iOS 1+"], [])
        checkAvail("@available(iOS, introduced: 1, obsoleted: 2)", ["iOS 1-2"], ["iOS - obsoleted in 2."])
        checkAvail("@available(iOS, obsoleted: 2)", ["iOS ?-2"], ["iOS - obsoleted in 2."])
        checkAvail("@available(iOS, introduced: 1, deprecated: 2)", ["iOS 1+"], ["iOS - deprecated in 2."])
        checkAvail("@available(iOS, introduced: 1, deprecated: 2, obsoleted: 3)", ["iOS 1-3"], ["iOS - obsoleted in 3."])
        checkAvail("@available(iOS, deprecated: 2, message: \"MSG\")", [], ["iOS - deprecated in 2. MSG."])
        checkAvail("@available(iOS, deprecated, message: \"MSG\")", [], ["iOS - deprecated. MSG."])
        checkAvail("@available(iOS, deprecated, message: \"MSG\", renamed: \"NU\")", [], ["iOS - deprecated. MSG. Renamed: `NU`."])
        checkAvail("@available(iOS, unavailable, message: \"MSG\", renamed: \"NU\")", [], ["iOS - unavailable. MSG. Renamed: `NU`."])

        // Syntax etc issues
        checkAvail("@available(dasdasd", [], [])
        checkAvail(#"@available(*, renamed: "NU\""#, [], [])
        checkAvail("@available(*, introduced: 123", [], [])
        checkAvail("@available(", [], [])
        checkAvail("@available(swift, something: 1, introduced: 2, introduced: 3)", [], [])
    }

    // Swift decl-piece-name

    private func checkPieces(_ pieces: [DeclarationPiece], _ str: String, file: StaticString = #file, line: UInt = #line) {
        var acc = ""
        pieces.forEach {
            switch $0 {
            case .name(let name): acc += "#\(name)#"
            case .other(let other): acc += other
            }
        }
        XCTAssertEqual(str, acc, file: file, line: line)
    }

    private func checkFuncPieces(_ decl: String, _ name: String, _ expect: String, file: StaticString = #file, line: UInt = #line) {
        let kind = DefKind.from(key: "source.lang.swift.decl.function.method.instance")!
        let builder = SwiftDeclarationBuilder(dict: [:], file: nil, kind: nil)
        let pieces = builder.parseToPieces(declaration: decl, name: name, kind: kind)
        checkPieces(pieces, expect, file: file, line: line)
    }

    func testFunctionPieces() {
        checkFuncPieces("func a(b c: Int = 2, d: String, _ e: Double)", "a",
                        "func #a#(#b#: Int, #d#: String, Double)")
        checkFuncPieces("func aaa(b: @escaping (_ c: Int) -> String) -> Int", "aaa",
                        "func #aaa#(#b#: (_ c: Int) -> String) -> Int")
        checkFuncPieces("func fff<T>() where T: Comparable", "fff",
                        "func #fff#<T>()")
        checkFuncPieces("func fff(a: Int) throws", "fff",
                        "func #fff#(#a#: Int)")
        checkFuncPieces("func fff(a: Int) rethrows -> String", "fff",
                        "func #fff#(#a#: Int) -> String")
    }

    func testSimplePieces() {
        let builder = SwiftDeclarationBuilder(dict: [:], file: nil, kind: nil)

        let classKind = DefKind.from(key: "source.lang.swift.decl.class")!
        let pieces = builder.parseToPieces(declaration: "class Fred: Barney", name: "Fred", kind: classKind)
        checkPieces(pieces, "class #Fred#")

        let varKind = DefKind.from(key: "source.lang.swift.decl.var.class")!
        let pieces2 = builder.parseToPieces(declaration: "class var fred: String { get }", name: "fred", kind: varKind)
        checkPieces(pieces2, "class var #fred#: String")
    }

    func testNearFunctionPieces() {
        let builder = SwiftDeclarationBuilder(dict: [:], file: nil, kind: nil)

        // Not entirely sure this is right for subscript!
        let subscriptKind = DefKind.from(key: "source.lang.swift.decl.function.subscript")!
        let pieces = builder.parseToPieces(declaration: "public subscript(newValue: Int) -> String", name: "subscript", kind: subscriptKind)
        checkPieces(pieces, "#subscript#(#newValue#: Int) -> String")

        let initKind = DefKind.from(key: "source.lang.swift.decl.function.constructor")!
        let pieces2 = builder.parseToPieces(declaration: "init()", name: "init", kind: initKind)
        checkPieces(pieces2, "#init#()")

        let pieces3 = builder.parseToPieces(declaration: "init(a b: Int)", name: "init", kind: initKind)
        checkPieces(pieces3, "#init#(#a#: Int)")
    }

    // Localization

    private func checkCommentLocalizations(_ cliArgs: [String], _ expect: [String], file: StaticString = #file, line: UInt = #line) throws {
        TestLogger.install()
        let pipeline = Pipeline()
        let args = ["--products", "files-json", "--module", "SpmSwiftModule2"] + cliArgs
        try pipeline.run(argv: args)
        guard let json = TestLogger.shared.outputBuf.first else {
            XCTFail("No output?", file: file, line: line)
            return
        }
        expect.forEach { expect in
            XCTAssertTrue(json.re_isMatch(#"abstract" : \{\n(.*?\n)? *".." : "\#(expect)""#), file: file, line: line)
        }
    }

    func testNoCommentBundle() throws {
        let srcURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try checkCommentLocalizations(["--default-localization=zh:ZH:zzz",
                                       "--doc-comment-language=en",
                                       "--doc-comment-languages-directory=\(srcURL.path)",
                                       "--source-directory=\(srcURL.path)"],
                                      ["English"])
        XCTAssertTrue(TestLogger.shared.diagsBuf.count > 0)
    }

    func testNoCommentString() throws {
        let srcURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try checkCommentLocalizations(["--default-localization=es:ES:eee",
                                       "--doc-comment-language=en",
                                       "--doc-comment-languages-directory=\(srcURL.path)",
                                       "--source-directory=\(srcURL.path)"],
                                      ["English"])
    }

    func testActualTranslation() throws {
        let srcURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try checkCommentLocalizations(["--localizations=fr:FR:fff",
                                       "--doc-comment-languages-directory=\(srcURL.path)",
                                       "--source-directory=\(srcURL.path)"],
                                      ["English", "French"])
    }

    func testFallbackToDefaultTranslation() throws {
        let srcURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try checkCommentLocalizations(["--default-localization=fr:FR:fff",
                                       "--localizations=es:ES:eee",
                                       "--doc-comment-language=en",
                                       "--doc-comment-languages-directory=\(srcURL.path)",
                                       "--source-directory=\(srcURL.path)"],
                                      ["French"])
    }

    func testNoLanguagesDirectory() throws {
        let srcURL = fixturesURL.appendingPathComponent("SpmSwiftPackage")
        try checkCommentLocalizations(["--default-localization=fr:FR:fff",
                                       "--doc-comment-language=en",
                                       "--source-directory=\(srcURL.path)"],
                                      ["English"])
    }
}
