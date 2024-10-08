//
//  TestMarkdown.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib
import Maaku

private let doc1 = Markdown("""
Abstract line.

Discussion para 1 of 2.

- not a callout

Discussion para 2 of 2.

- returns: The answer -
  On two lines.

- localizationKey: en

- parameter Fred: Barney
""")

private let doc2 = Markdown("""
- parameters:
    - fred: wilma
    - barney: betty
""")

private let doc3 = Markdown("")


class TestMarkdown: XCTestCase {
    // Basic callout detection
    private func checkCallout(_ str: String, _ title: String, _ body: String, _ format: CMCallout.Format,
                              file: StaticString = #filePath, line: UInt = #line) {
        guard let callout = CMCallout(string: str) else {
            XCTFail("No callout", file: file, line: line)
            return
        }
        XCTAssertEqual(title, callout.title, file: file, line: line)
        XCTAssertEqual(body, callout.body, file: file, line: line)
        XCTAssertEqual(format, callout.format, file: file, line: line)
    }

    private func checkNoCallout(_ str: String, file: StaticString = #filePath, line: UInt = #line) {
        if let callout = CMCallout(string: str) {
            XCTFail("Callout: \(callout)", file: file, line: line)
        }
    }

    func testCalloutDetection() {
        checkCallout("a: b", "a", "b", .other)
        checkCallout("a  :b", "a", "b", .other)
        checkCallout("callout(fred): barney", "fred", "barney", .custom)
        checkCallout("  callout(fred) :  barney", "fred", "barney", .custom)
        checkCallout("paraMeters:", "paraMeters", "", .other)
        checkCallout("parameter fred: barney", "fred", "barney", .parameter)
        checkCallout("Parameter: fred barney", "fred", "barney", .parameter)

        checkNoCallout("param fred: barney")
        checkNoCallout("callout (fred): barney")
    }

    func testDestructure1() {
        let m = MarkdownBuilder(markdown: doc1, source: .docComment)
        guard let results = m.build() else {
            XCTFail("Failed")
            return
        }
        XCTAssertEqual(m.localizationKey, "en")
        XCTAssertEqual(results.returns, Markdown("The answer -\nOn two lines."))
        XCTAssertEqual(results.parameters, [FlatDefDocs.Param(name: "Fred", description: Markdown("Barney"))])
        XCTAssertEqual(results.abstract, Markdown("Abstract line."))
        XCTAssertEqual(results.discussion, Markdown("""
           Discussion para 1 of 2.

             - not a callout

           Discussion para 2 of 2.

             - localizationKey: en
           """))
    }

    func testDestructure2() {
        let m = MarkdownBuilder(markdown: doc2, source: .docComment)
        guard let results = m.build() else {
            XCTFail("Failed")
            return
        }
        XCTAssertNil(m.localizationKey)
        XCTAssertNil(results.returns)
        XCTAssertEqual(results.parameters,
                       [FlatDefDocs.Param(name: "fred", description: Markdown("wilma")),
                        FlatDefDocs.Param(name: "barney", description: Markdown("betty"))])
        XCTAssertNil(results.abstract)
        XCTAssertNil(results.discussion)
    }

    func testDestructure3() {
        let m = MarkdownBuilder(markdown: doc3, source: .docComment)
        guard let results = m.build() else {
            XCTFail("Failed")
            return
        }
        XCTAssertNil(m.localizationKey)
        XCTAssertNil(results.returns)
        XCTAssertEqual(results.parameters, [])
        XCTAssertNil(results.abstract)
        XCTAssertEqual(results.discussion, Markdown(""))
    }

    // Formatting part

    func testBaseFormatting() {
        let formatter = MarkdownFormatter(language: .swift)
        let mdIn = Markdown("text")
        let (mdOut, html) = formatter.format(md: mdIn, languageTag: "en")
        XCTAssertEqual("<p>text</p>", html.value)
        XCTAssertEqual(mdIn, mdOut)
        let (mdInlineOut, htmlInline) = formatter.formatInline(md: mdIn, languageTag: "en")
        XCTAssertEqual("text", htmlInline.value)
        XCTAssertEqual(mdIn, mdInlineOut)
    }

    func testHeadingFormatting() {
        let formatter = MarkdownFormatter(language: .swift)
        let md = Markdown("# Heading Text")
        let (_, html) = formatter.format(md: md, languageTag: "en")
        XCTAssertEqual(
            #"""
            <h1 class="j2-anchor j2-heading heading" id="heading-text">
            <span data-anchor-id="heading-text">
            Heading Text
            </span></h1>
            """#,
            html.value)
    }

    private func checkLanguage(in: String, out: String, line: UInt = #line) {
        let formatter = MarkdownFormatter(language: .swift)
        let md = Markdown("""
                          ```\(`in`)
                          text
                          ```
                          """)
        let (_, html) = formatter.format(md: md, languageTag: "en")
        XCTAssertTrue(html.value.contains("language-\(out)"))
    }

    func testCodeBlockFormatting() {
        checkLanguage(in: "", out: "swift")
        checkLanguage(in: "swift", out: "swift")
        checkLanguage(in: "ruby", out: "ruby")
        checkLanguage(in: "objectivec", out: "objectivec")
        checkLanguage(in: "objc", out: "objectivec")
    }

    func testCalloutFormatting() {
        let formatter = MarkdownFormatter(language: .swift)
        let md = Markdown("""
                          - warning: Warning
                          - callout(Custom Callout): Custom
                          """)
        let (_, html) = formatter.format(md: md, languageTag: "en")
        XCTAssertEqual("""
            <div class="j2-callout j2-callout-warning aside aside-warning">
            <div class="j2-callout-title aside-title" role="heading" aria-level="6">warning</div>
            <p>Warning</p>
            </div>
            <div class="j2-callout j2-callout-custom-callout aside aside-custom-callout">
            <div class="j2-callout-title aside-title" role="heading" aria-level="6">Custom Callout</div>
            <p>Custom</p>
            </div>
            """, html.value)
    }

    func testParaMunging() throws {
        let para = Markdown("Text")
        XCTAssertEqual("  - Text", CMDocument.parasToList(markdown: para).value)

        let paras = Markdown("""
                             Text

                             Text2
                             """)
        XCTAssertEqual("  - Text\n\n  - Text2", CMDocument.parasToList(markdown: paras).value)
    }
}
