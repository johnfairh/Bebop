//
//  TestMarkdown.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
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
                              file: StaticString = #file, line: UInt = #line) {
        guard let callout = CMCallout(string: str) else {
            XCTFail("No callout", file: file, line: line)
            return
        }
        XCTAssertEqual(title, callout.title, file: file, line: line)
        XCTAssertEqual(body, callout.body, file: file, line: line)
        XCTAssertEqual(format, callout.format, file: file, line: line)
    }

    private func checkNoCallout(_ str: String, file: StaticString = #file, line: UInt = #line) {
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
        let m = MarkdownBuilder(markdown: doc1)
        guard let results = m.build() else {
            XCTFail("Failed")
            return
        }
        XCTAssertEqual(m.localizationKey, "en")
        XCTAssertEqual(results.returns, Markdown("The answer - On two lines."))
        XCTAssertEqual(results.parameters, [FlatDefDocs.Param(name: "Fred", description: Markdown("Barney"))])
        XCTAssertEqual(results.abstract, Markdown("Abstract line."))
        XCTAssertEqual(results.overview, Markdown("""
           Discussion para 1 of 2.

             - not a callout

           Discussion para 2 of 2.

             - localizationKey: en
           """))
    }

    func testDestructure2() {
        let m = MarkdownBuilder(markdown: doc2)
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
        XCTAssertNil(results.overview)
    }

    func testDestructure3() {
        let m = MarkdownBuilder(markdown: doc3)
        guard let results = m.build() else {
            XCTFail("Failed")
            return
        }
        XCTAssertNil(m.localizationKey)
        XCTAssertNil(results.returns)
        XCTAssertEqual(results.parameters, [])
        XCTAssertNil(results.abstract)
        XCTAssertEqual(results.overview, Markdown(""))
    }
}
