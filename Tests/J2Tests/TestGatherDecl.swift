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

class TestGatherDecl: XCTestCase {
    // Annotated XML parse
    private func fullyAnnotatedToString(_ xml: String) -> String? {
        // doesn't matter what outer element is, just that it's there
        let realXML = "<decl.function.method.instance>\(xml)</decl.function.method.instance>"
        let dict = ["key.fully_annotated_decl" : realXML]
        let builder = SwiftDeclarationBuilder(dict: dict, file: nil)
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
        XCTAssertNil(SwiftDeclarationBuilder(dict: [:], file: nil).build())

        let badDict = ["key.fully_annotated_decl" : "<open text"]
        XCTAssertNil(SwiftDeclarationBuilder(dict: badDict, file: nil).build())
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    // 'orrible parsed text regular expressions
    func testParsedDecl() {
        let b = SwiftDeclarationBuilder(dict: [:], file: nil)
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
        let dict = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                    "key.parsed_declaration" : "One\nTwo"]
        let builder = SwiftDeclarationBuilder(dict: dict, file: nil)
        let decl = builder.build()
        XCTAssertEqual("One\nTwo", decl?.declaration)

        let dict2 = ["key.fully_annotated_decl" : "<outer>Inner</outer>",
                     "key.parsed_declaration" : "One Two"]
        let builder2 = SwiftDeclarationBuilder(dict: dict2, file: nil)
        let decl2 = builder2.build()
        XCTAssertEqual("Inner", decl2?.declaration)
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
             "key.fully_annotated_decl": "<outer>public func fred()</outer"]
        let builder = SwiftDeclarationBuilder(dict: dict, file: file)
        
        let parsed = builder.parse(attributeDicts: attrDicts)
        XCTAssertEqual(["@discardableResult"], parsed)

        guard let built = builder.build() else {
            XCTFail("Couldn't build decl-info")
            return
        }
        XCTAssertEqual("@discardableResult\npublic func fred()", built.declaration)
    }
}
