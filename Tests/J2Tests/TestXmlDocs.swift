//
//  TestXmlDocs.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import Maaku

class BuilderClient {
    var builder: XMLDocBuilder?
    var doc: CMNode?

    init() {
        builder = nil
        doc = nil
        builder = XMLDocBuilder() { [weak self] in
            self?.startElement(element: $0, attrs: $1)
        }
    }

    func startElement(element: String, attrs: [String : String]) {
        if element == "Document" {
            XCTAssertNil(doc)
            builder?.startDocument() { self.doc = $0 }
        }
    }

    func parse(xml: String) throws {
        try builder?.parse(xml: xml)
    }
}


class TestXMLDocs: XCTestCase {

    func testNotInterested() throws {
        let xml = """
                  <Nothing>
                  Random text
                  <Para>Here is some text.</Para>
                  <Para>Here is some more.</Para>
                  </Nothing>
                  """

        let client = BuilderClient()
        try client.parse(xml: xml)
        XCTAssertNil(client.doc)
    }

    func testNotXml() throws {
        let xml = "really not xml"
        let client = BuilderClient()
        AssertThrows(try client.parse(xml: xml), J2Error.self)
    }

    func testBase() throws {
        let xml = """
                  <Document>
                  <Para>Para 1.</Para>
                  <Para>Para 2.</Para>
                  </Document>
                  """

        let client = BuilderClient()
        try client.parse(xml: xml)
        XCTAssertNotNil(client.doc)
        XCTAssertEqual("Para 1.\n\nPara 2.", client.doc?.renderPlainText())
    }
}
