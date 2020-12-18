//
//  TestGatherDecl.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib
import SourceKittenFramework

// Declaration parsing

extension SwiftDeclarationBuilder {
    convenience init(dict: SourceKittenDict, nameComponents: [String] = [], file: File? = nil, kind: DefKind? = nil) {
        self.init(dict: dict, nameComponents: nameComponents, file: file, kind: kind, stripObjC: false, availabilityRules: Gather.Availability())
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
        let classKind = DefKind.from(kind: SwiftDeclarationKind.class)
        let dict = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                    "key.parsed_declaration" : "One\nTwo"]
        let builder = SwiftDeclarationBuilder(dict: dict, kind: classKind)
        let decl = builder.build()
        XCTAssertEqual("One\nTwo", decl?.declaration.text)

        let dict2 = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                     "key.parsed_declaration" : "One Two"]
        let builder2 = SwiftDeclarationBuilder(dict: dict2, kind: classKind)
        let decl2 = builder2.build()
        XCTAssertEqual("Inner", decl2?.declaration.text)

        let extKind = DefKind.from(kind: SwiftDeclarationKind.extension)
        let extDict = ["key.fully_annotated_decl" : "<outer>class Fred</outer>",
                       "key.parsed_declaration" : "extension Fred"]
        let extBuilder = SwiftDeclarationBuilder(dict: extDict, kind: extKind)
        let extDecl = extBuilder.build()
        XCTAssertEqual("extension Fred", extDecl?.declaration.text)

        let varKind = DefKind.from(kind: SwiftDeclarationKind.varClass)
        let varDict = ["key.fully_annotated_decl" : "<outer>var toast { get set }</outer>",
                       "key.parsed_declaration" : "var toast = { blah\n }()"]
        let varBuilder = SwiftDeclarationBuilder(dict: varDict, kind: varKind)
        let varDecl = varBuilder.build()
        XCTAssertEqual("var toast { get set }", varDecl?.declaration.text)
    }

    func testParentTypes() {
        let classKind = DefKind.from(kind: SwiftDeclarationKind.class)
        ["Outer.Inner", "Outer&lt;S&gt;.Inner", "Outer&lt;A, B:C&gt;.Inner"].forEach { innerClassName in
            let dict = ["key.fully_annotated_decl" : "<outer>class \(innerClassName)</outer>"]
            let builder = SwiftDeclarationBuilder(dict: dict, nameComponents: ["Outer", "Inner"], kind: classKind)
            let decl = builder.build()
            XCTAssertEqual("class Inner", decl?.declaration.text, "Original: \(innerClassName)")
        }

        let dict = ["key.fully_annotated_decl" : "<outer>class A&lt;B&gt;.C.D</outer>"]
        let builder = SwiftDeclarationBuilder(dict: dict, nameComponents: ["A", "C", "D"], kind: classKind)
        let decl = builder.build()
        XCTAssertEqual("class D", decl?.declaration.text)

        let builder2 = SwiftDeclarationBuilder(dict: dict, nameComponents: ["A", "D"], kind: classKind)
        let decl2 = builder2.build()
        XCTAssertEqual("class A<B>.C.D", decl2?.declaration.text)
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
        
        let parsed = builder.parseAttributes(dicts: attrDicts, from: file)
        XCTAssertEqual(["@discardableResult"], parsed)

        guard let built = builder.build() else {
            XCTFail("Couldn't build decl-info")
            return
        }
        XCTAssertEqual("@discardableResult\npublic func fred()", built.declaration.text)
    }

    private func checkAvailabilityControl(_ availabilityRules: Gather.Availability, _ expect: [String], line: UInt = #line) {
        let file = File(contents: "@available(iOS, introduced: 1) func fred() {}")

        let attrDicts: [SourceKittenDict] = [
            ["key.attribute" : "source.decl.attribute.available",
             "key.length": Int64(30),
             "key.offset": Int64(0)]]
        let dict: SourceKittenDict = [
            "key.attributes": attrDicts,
            "key.fully_annotated_decl": "<outer>func fred()</outer>"]
        let builder = SwiftDeclarationBuilder(dict: dict, nameComponents: [], file: file, kind: nil, stripObjC: false, availabilityRules: availabilityRules)
        guard let built = builder.build() else {
            XCTFail("Couldn't build decl-info", line: line)
            return
        }
        XCTAssertEqual(expect, built.availability)
    }

    func testAvailabilityControl() {
        checkAvailabilityControl(Gather.Availability(), ["iOS 1+"])
        checkAvailabilityControl(Gather.Availability(defaults: [], ignoreAttr: true), [])
        checkAvailabilityControl(Gather.Availability(defaults: ["Def"], ignoreAttr: false), ["Def", "iOS 1+"])
        checkAvailabilityControl(Gather.Availability(defaults: ["Def"], ignoreAttr: true), ["Def"])
        checkAvailabilityControl(Gather.Availability(defaults: ["Def1", "Def2"], ignoreAttr: true), ["Def1", "Def2"])
    }

    // Available empire.  or at least a satrapie.
    private func checkAvail(_ available: String, _ expectAvail: [String], _ expectDeprecations: [String], _ expectUnavail: [String] = [],
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

        let unavailable: [String]
        if builder.unavailables.count > 0 {
            unavailable = [(builder.unavailables[0])["en"]!]
        } else {
            unavailable = []
        }

        XCTAssertEqual(expectDeprecations, deprecation, file: file, line: line)
        XCTAssertEqual(expectUnavail, unavailable, file: file, line: line)
    }

    func testAvailable() {
        checkAvail("@available(swift 5, *)", ["swift 5+"], [])
        checkAvail("@available (iOS 13,macOS 12 ,*)", ["iOS 13+", "macOS 12+"], [])
        checkAvail("@available(*, unavailable)", [], [], [])
        checkAvail("@available(*, unavailable, message: \"MSG\" )", [], [], ["Unavailable. MSG."])
        checkAvail("@available(*, unavailable, message: \"MSG\", renamed: \"NU\" )",
                   [], [], ["Unavailable. MSG. Renamed to `NU`."])
        checkAvail("@available(*, deprecated, renamed: \"NU\" )",
                   [], ["Deprecated. Renamed to `NU`."])
        checkAvail("@available(iOS, introduced: 1)", ["iOS 1+"], [])
        checkAvail("@available(iOS, introduced: 1, obsoleted: 2)", ["iOS 1-2"], ["iOS - obsoleted since 2."])
        checkAvail("@available(iOS, obsoleted: 2)", ["iOS ?-2"], ["iOS - obsoleted since 2."])
        checkAvail("@available(iOS, introduced: 1, deprecated: 2)", ["iOS 1+"], ["iOS - deprecated since 2."])
        checkAvail("@available(iOS, introduced: 1, deprecated: 2, obsoleted: 3)", ["iOS 1-3"], ["iOS - obsoleted since 3."])
        checkAvail("@available(iOS, deprecated: 2, message: \"MSG\")", [], ["iOS - deprecated since 2. MSG."])
        checkAvail("@available(iOS, deprecated, message: \"MSG\")", [], ["iOS - deprecated. MSG."])
        checkAvail("@available(iOS, deprecated, message: \"MSG\", renamed: \"NU\")", [], ["iOS - deprecated. MSG. Renamed to `NU`."])
        checkAvail("@available(iOS, unavailable, message: \"MSG\\\"\", renamed: \"NU\")", [], [], ["iOS - unavailable. MSG\\\". Renamed to `NU`."])
        checkAvail("@available(iOS, unavailable)", [], [], [])

        // Syntax etc issues
        checkAvail("@available(dasdasd", [], [])
        checkAvail(#"@available(*, renamed: "NU\""#, [], [])
        checkAvail("@available(*, introduced: 123", [], [])
        checkAvail("@available(", [], [])
        checkAvail("@available(swift, something: 1, introduced: 2, introduced: 3)", [], [])
    }

    // Swift decl-piece-name

    private func checkFuncPieces(_ decl: String, _ name: String, _ expect: String, line: UInt = #line) {
        let kind = DefKind.from(kind: SwiftDeclarationKind.functionMethodInstance)
        let builder = SwiftDeclarationBuilder(dict: [:], file: nil, kind: nil)
        let pieces = builder.parseToPieces(declaration: decl, name: name, kind: kind)
        XCTAssertEqual(expect, pieces.flat, line: line)
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

        let classKind = DefKind.from(kind: SwiftDeclarationKind.class)
        let pieces = builder.parseToPieces(declaration: "class Fred: Barney", name: "Fred", kind: classKind)
        XCTAssertEqual("class #Fred#", pieces.flat)

        let varKind = DefKind.from(kind: SwiftDeclarationKind.varClass)
        let pieces2 = builder.parseToPieces(declaration: "class var fred: String { get }", name: "fred", kind: varKind)
        XCTAssertEqual("class var #fred#: String", pieces2.flat)

        let pieces3 = builder.parseToPieces(declaration: "class var `true`: String { get }", name: "true", kind: varKind)
        XCTAssertEqual("class var #true#: String", pieces3.flat)
    }

    func testNearFunctionPieces() {
        let builder = SwiftDeclarationBuilder(dict: [:], file: nil, kind: nil)

        // Not entirely sure this is right for subscript!
        let subscriptKind = DefKind.from(kind: SwiftDeclarationKind.functionSubscript)
        let pieces = builder.parseToPieces(declaration: "public subscript(newValue: Int) -> String { get }", name: "subscript", kind: subscriptKind)
        XCTAssertEqual("#subscript#(#newValue#: Int) -> String", pieces.flat)

        let staticSubscriptKind = DefKind.from(key: SwiftDeclarationKind.functionSubscript.rawValue,
                                               dict: [SwiftDocKey.name.rawValue: "subscript",
                                                      SwiftDocKey.parsedDeclaration.rawValue: "static subscript(a: Int)"])!
        let pieces1 = builder.parseToPieces(declaration: "public static subscript(newValue: Int) -> String { get }", name: "subscript", kind: staticSubscriptKind)
        XCTAssertEqual("static #subscript#(#newValue#: Int) -> String", pieces1.flat)

        let initKind = DefKind.from(key: SwiftDeclarationKind.functionMethodInstance.rawValue, dict: [SwiftDocKey.name.rawValue:"init?()"])!
        let pieces2 = builder.parseToPieces(declaration: "init()", name: "init()", kind: initKind)
        XCTAssertEqual("#init#()", pieces2.flat)

        let pieces3 = builder.parseToPieces(declaration: "init(a b: Int)", name: "init(b:)", kind: initKind)
        XCTAssertEqual("#init#(#a#: Int)", pieces3.flat)

        let deinitKind = DefKind.from(key: SwiftDeclarationKind.functionMethodInstance.rawValue, dict: [SwiftDocKey.name.rawValue:"deinit"])!
        let pieces4 = builder.parseToPieces(declaration: "deinit", name: "deinit", kind: deinitKind)
        XCTAssertEqual("#deinit#", pieces4.flat)

        let operatorKind = DefKind.from(key: SwiftDeclarationKind.functionOperator.rawValue, dict: [
            SwiftDocKey.name.rawValue: "+(_:_)",
            SwiftDocKey2.fullyAnnotatedDecl.rawValue: "<decl.function.operator.infix>func +(lhs: T, rhs: T) -&gt; T</decl.function.operator.infix>"
        ])!
        let pieces5 = builder.parseToPieces(declaration: "func +(lhs: T, rhs: T) -> T", name: "+(_:_)", kind: operatorKind)
        XCTAssertEqual("static func #+#(#lhs#: T, #rhs#: T) -> T", pieces5.flat)
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

extension Array where Element == DeclarationPiece {
    var flat: String {
        var acc = ""
        forEach {
            switch $0 {
            case .name(let name): acc += "#\(name)#"
            case .other(let other): acc += other
            }
        }
        return acc
    }
}
