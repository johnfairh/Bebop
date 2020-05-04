//
//  GatherXMLDocs.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif // rude comment
import Maaku

/// Wackiness to turn an XML doc comment into markdown for uniform processing by the rest
/// of the program.
///
/// Heavily derived from `TMLXMLToMarkdown` by 2017 me -- this version is much easier because
/// we can target the CM AST instead of literal redcarpet-compatible markdown text.
///
/// Apple's XML format here is pretty silly, pushing way too much stuff through raw HTML.  We don't
/// go too far making this work neatly in markdown.
///

// MARK: XMLDocBuilder

/// The XML we expect contains a mixture of markdown docs and structural elements like 'Discussion'.
/// and other less relevant things.
///
/// This layer understands the former but not the latter.  When it encounters a structural element
/// it punts to its `StartElement` client who may request some type of action from the builder
/// on the XML found within the element.
///
final class XMLDocBuilder: NSObject, XMLParserDelegate {
    typealias StartElementFn = (String, [String : String]) -> Void

    private var startElement: StartElementFn

    init(startElement: @escaping StartElementFn) {
        self.startElement = startElement
    }

    // State tracking current client request
    typealias DocBuiltFn = (CMNode) -> Void
    private var currentDocBuilt: DocBuiltFn?
    private var currentDocument: CMNode?

    // Callback interface to client
    private enum StartElementState {
        case idle, active, recalled
    }
    private var startElementState = StartElementState.idle
    private func issueStartElement(_ name: String, attrs: [String : String]) -> Bool {
        precondition(startElementState == .idle)
        startElementState = .active
        defer { startElementState = .idle }
        startElement(name, attrs)
        return startElementState == .recalled
    }

    /// Client call from the `StartElement` callback to actually start building a markdown document
    func startDocument(callback: @escaping DocBuiltFn) {
        precondition(currentDocument == nil)
        precondition(currentDocBuilt == nil)
        precondition(startElementState == .active)
        startElementState = .recalled
        currentDocument = CMNode(type: .document)
        currentDocBuilt = callback
    }

    private func endDocument() {
        precondition(currentDocument != nil)
        precondition(currentDocBuilt != nil)
        currentDocBuilt!(currentDocument!)
        currentDocument = nil
        currentDocBuilt = nil
    }

    // Parser interface
    private var xmlParser: XMLParser!

    /// Client blocking call to run the docbuilder over some XML
    func parse(xml: String) throws {
        let saferString = xml.replacingOccurrences(of: "\n", with: "")
        xmlParser = XMLParser(data: saferString.data(using: .utf8)!)
        xmlParser.delegate = self
        defer { xmlParser = nil }

        guard xmlParser.parse() else {
            let errStr = String(describing: xmlParser.parserError)
            throw J2Error("XMLParser failed: \(errStr), line \(xmlParser.lineNumber) column \(xmlParser.columnNumber)")
        }
    }

    // Actual parser logic

    /// XML element names we recognize as part of markdown
    /// Get a load of these names.... words fail.
    private enum Element: String {
        case para              = "Para"
        case bold              = "bold"
        case emphasis          = "emphasis"
        case codeVoice         = "codeVoice"
        case codeListing       = "CodeListing"
        case zCodeLineNumbered = "zCodeLineNumbered"
        case link              = "Link"
        case rawHTML           = "rawHTML"
        case listBullet        = "List-Bullet"
        case listNumber        = "List-Number"
        case item              = "Item"
    }

    /// We push on the way down and pop+execute on the way back up
    private typealias ElementDoneFn = () -> Void
    private var elementDoneStack = [ElementDoneFn?]()
    private func doOnElementDone(call: @escaping ElementDoneFn) {
        elementDoneStack.append(call)
    }
    private func nopOnElementDone() {
        elementDoneStack.append(nil)
    }
    private func elementDone() {
        elementDoneStack.removeLast()?()
    }

    private var currentParent: CMNode?

    private func newParentUntilElementDone(_ newParent: CMNode, and: ElementDoneFn? = nil) {
        let oldCurrentParent = self.currentParent
        self.currentParent = newParent
        doOnElementDone {
            self.currentParent = oldCurrentParent
            and?()
        }
    }

    /// State for accumulating code block content.
    /// This is a bit ugly because of the way the XML models it.
    private var codeBlockContent = ""
    private var codeBlockCurrentLine = ""

    /// State for handling raw HTML nodes
    private enum RawHTMLState {
        case idle, inside, startElement(CMNode), endElement

        var isIdle: Bool {
            if case .idle = self { return true } else { return false }
        }

        var isStartElement: CMNode? {
            guard case let .startElement(node) = self else {
                return nil
            }
            return node
        }

        var isEndElement: Bool {
            if case .endElement = self { return true } else { return false }
        }
    }

    private var rawHTMLState = RawHTMLState.idle

    /// Spot interesting elements, do something + schedule more work for when the element ends.
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String : String]) {

        let depth = elementDoneStack.count
        defer { precondition(elementDoneStack.count == depth + 1, "Forgot to push done-stack")}

        // 1 - look for structural elements and call out to the client

        guard let element = Element(rawValue: elementName) else {
            // Not a markdown element, let client handle it
            let clientInterested = issueStartElement(elementName, attrs: attributeDict)
            if clientInterested {
                precondition(currentParent == nil) // overlapping
                precondition(currentDocument != nil)
                currentParent = currentDocument
            }
            doOnElementDone {
                if clientInterested {
                    precondition(self.currentParent != nil)
                    self.currentParent = nil
                    self.endDocument()
                }
            }
            return
        }

        // 2 - abandon if we're not interested in turning this part
        //     of the document into markdown

        guard let currentParent = currentParent else {
            nopOnElementDone()
            return
        }

        // 3 - build up the markdown tree

        switch element {
        case .emphasis:
            let emphNode = CMNode(type: .emphasis)
            try! emphNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(emphNode)

        case .bold:
            let strNode = CMNode(type: .strong)
            try! strNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(strNode)

        case .codeVoice:
            let codeNode = CMNode(type: .code)
            try! codeNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(codeNode)

        case .link:
            let linkNode = CMNode(type: .link)
            try! linkNode.setLinkDestination(attributeDict["href"] ?? "")
            try! linkNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(linkNode)

        case .para:
            let paraNode = CMNode(type: .paragraph)
            try! paraNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(paraNode)

        case .codeListing:
            let codeNode = CMNode(type: .codeBlock)
            if let language = attributeDict["language"] {
                try! codeNode.setFencedCodeInfo(language)
            }
            try! codeNode.insertIntoTree(asLastChildOf: currentParent)
            precondition(codeBlockContent.isEmpty)
            // All the content of the block goes into this node's literal,
            // but in XML there is an overengineered hierarchy going on that
            // we collect using parser-global state.
            newParentUntilElementDone(codeNode) {
                try! codeNode.setLiteral(self.codeBlockContent)
                self.codeBlockContent = ""
            }

        case .zCodeLineNumbered:
            // The line content is optional and comes in thru CDATA...
            precondition(codeBlockCurrentLine.isEmpty)
            doOnElementDone {
                self.codeBlockContent += self.codeBlockCurrentLine + "\n"
                self.codeBlockCurrentLine = ""
            }
            break

        case .rawHTML:
            // These elements may be genuinely raw html or, more likely, wrapping
            // normal things that mysteriously aren't expressed in XML.  So we hold
            // off creating a node until we get the CDATA for the actual HTML.
            //
            // Worse, headings are expressed as pairs of <hX> and </hX> elements.
            // This messes up the tree mapping so we have to fix this up.
            precondition(rawHTMLState.isIdle)
            rawHTMLState = .inside
            doOnElementDone {
                precondition(!self.rawHTMLState.isIdle)
                if let newParentNode = self.rawHTMLState.isStartElement {
                    self.newParentUntilElementDone(newParentNode)
                } else if self.rawHTMLState.isEndElement {
                    self.elementDone()
                }
                self.rawHTMLState = .idle
            }

        case .listBullet, .listNumber:
            let listNode = CMNode(type: .list)
            if element == .listNumber {
                try! listNode.setListType(.ordered)
                try! listNode.setListStartingNumber(1)
            }
            try! listNode.setListTight(true)
            try! listNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(listNode)

        case .item:
            let itemNode = CMNode(type: .item)
            try! itemNode.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(itemNode)
        }
    }

    /// End of element - just process whatever was saved when the element opened.
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        elementDone()
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentParent = currentParent else {
            // Not turning this part of the doc into markdown
            return
        }
        if currentParent.type == .code {
            try! currentParent.setLiteral(string)
        } else {
            let node = CMNode(type: .text)
            try! node.setLiteral(string)
            try! node.insertIntoTree(asLastChildOf: currentParent) // XXX need error checking on this
        }
    }

    /// CDATA.  Used for html, doc elements that are 'too complex to express in XML', each line of a code block.
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let currentParent = currentParent else {
            // Not turning this part of the doc into markdown
            return
        }

        guard let cdataString = String(data: CDATABlock, encoding: .utf8) else {
            logWarning("XML parse error with CDATA: \(CDATABlock)")
            return
        }

        if currentParent.type == .codeBlock {
            precondition(codeBlockCurrentLine.isEmpty)
            codeBlockCurrentLine = cdataString
            return
        }

        guard !rawHTMLState.isIdle else {
            // CDATA in some random element?
            let node = CMNode(type: .text)
            try! node.setLiteral(cdataString)
            try! node.insertIntoTree(asLastChildOf: currentParent)
            return
        }

        if cdataString == "<hr/>" {
            let hrNode = CMNode(type: .thematicBreak)
            try! hrNode.insertIntoTree(asLastChildOf: currentParent)
        } else if cdataString == "<br/>" {
            let brNode = CMNode(type: .lineBreak)
            try! brNode.insertIntoTree(asLastChildOf: currentParent)
        } else if let match = cdataString.re_match(#"^<h(\d)>$"#) {
            let headingNode = CMNode(type: .heading)
            try! headingNode.setHeadingLevel(Int32(match[1])!)
            try! headingNode.insertIntoTree(asLastChildOf: currentParent)
            rawHTMLState = .startElement(headingNode)
        } else if cdataString.re_isMatch(#"^</h\d>$"#) {
            rawHTMLState = .endElement
        } else if let match = cdataString.re_match(#"<img src="(.*?)"(?: title="(.*?)")?(?: alt="(.*?)")?/>"#) {
            // side-eye at commonmark this time - link alt text is a child markdown tree rendered as plaintext...
            let imgNode = CMNode(type: .image)
            try! imgNode.setLinkDestination(match[1])
            try! imgNode.setLinkTitle(match[2])
            let altTextNode = CMNode(type: .text)
            try! altTextNode.setLiteral(match[3])
            try! altTextNode.insertIntoTree(asFirstChildOf: imgNode)
            try! imgNode.insertIntoTree(asLastChildOf: currentParent)
        } else {
            let rawHTMLNode = CMNode(type: .htmlBlock) // sure
            try! rawHTMLNode.setLiteral(cdataString)
            try! rawHTMLNode.insertIntoTree(asLastChildOf: currentParent)
        }
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        logWarning("XML parse error handling inherited doc comment: \(parseError).")
    }
}
