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
#endif // just...
import Maaku

/// Wackiness to turn an XML doc comment into markdown for uniform processing by the rest
/// of the program.
///
/// Heavily derived from `TMLXMLToMarkdown` by 2017 me -- this is much easier because we
/// can target the CM AST instead of literal redcarpet-compatible markdown text.
///
/// Apple's XML format here is pretty silly, pushing way too much stuff through raw HTML.  We don't
/// go too far making this work neatly in markdown - in particular this implementation doesn't bother
/// transforming <img> elements.  Can revisit if Xcode ever fixes quick help to render images -- see
/// TMLXTM.
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
        case strong            = "strong"
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

    /// Leftover from redcarpet model but good enough: we push on the way down and pop+execute
    /// on the way back - client stuff hooks if necessary to emit docs
    private typealias ElementDoneFn = () -> Void
    private var elementDoneStack = [ElementDoneFn?]()

// ? don't need
//
//    /// Stop parsing elements immediately
//    public func abort() {
//        xmlParser?.abortParsing()
//    }

    private var currentParent: CMNode?

    /// Spot interesting elements, do something + schedule more work for when the element ends.
    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String : String]) {

        // 1 - look for structural elements and call out to the client

        guard let element = Element(rawValue: elementName) else {
            // Not a markdown element, let client handle it
            let clientInterested = issueStartElement(elementName, attrs: attributeDict)
            if clientInterested {
                precondition(currentParent == nil) // overlapping
                precondition(currentDocument != nil)
                currentParent = currentDocument
            }
            elementDoneStack.append {
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
            elementDoneStack.append(nil)
            return
        }

        // 3 - build up the markdown tree

        var elementDone: ElementDoneFn? = nil

        func pushCurrentParent(newParent: CMNode) {
            self.currentParent = newParent
            elementDone = { self.currentParent = currentParent }
        }

        switch element {
//        case .emphasis:
//            output += "*"
//            elementDone = { self.output += "*" }
//        case .strong:
//            output += "**"
//            elementDone = { self.output += "**" }
//        case .codeVoice:
//            output += "`"
//            elementDone = { self.output += "`" }
//
//        case .link:
//            output += "["
//            elementDone = {
//                let href = attributeDict["href"] ?? ""
//                self.output += "](\(href))" // apple markdown doesn't support a 'title' here...
//            }

        case .para:
            let paraNode = CMNode(type: .paragraph)
            try! paraNode.insertIntoTree(asLastChildOf: currentParent)
            pushCurrentParent(newParent: paraNode)

//        case .codeListing:
//            output += whitespace.newlineAndPrefix() + "```" + (attributeDict["language"] ?? "") + "\n"
//            inside.insert(.codeListing)
//            elementDone = {
//                self.output += self.whitespace.prefix() + "```\n"
//                self.inside.remove(.codeListing)
//            }
//        case .zCodeLineNumbered:
//            break
//
//        case .rawHTML:
//            // Can be block or inline :(  If block then have to do indent + paragraphing.
//            if !inside.contains(.para) {
//                output += whitespace.newlineAndPrefix()
//                elementDone = {
//                    if !self.inside.contains(.htmlHeading) {
//                        self.output += "\n"
//                    }
//                    self.inside.remove(.htmlHeading)
//                }
//            }
//
//        case .listBullet, .listNumber:
//            // note new bullet type, restore current type after element
//            let currentList = inside.intersection(.allLists)
//            inside.remove(.allLists)
//            inside.insert(element == .listBullet ? .listBullet : .listNumber)
//
//            // redcarpet 'hmm', must have blank line iff not currently inside a list
//            if currentList == .nothing {
//                output += whitespace.newline()
//            }
//            whitespace.indent()
//            elementDone = {
//                self.inside.remove(.allLists)
//                self.inside.insert(currentList)
//                self.whitespace.outdent()
//            }
//
//        case .item:
//            output += whitespace.listItemPrefix()
//            if inside.contains(.listBullet) {
//                output += "- "
//            } else {
//                output += "1. " // thankfully we can cheat here :)
//            }
//            // no indent for whatever is next, follows bullet directly
//            whitespace.skipNext()
        default:
            break
        }

        elementDoneStack.append(elementDone)
    }

    /// End of element - just process whatever was saved when the element opened.
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        elementDoneStack.removeLast()?()
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentParent = currentParent else {
            // Not turning this part of the doc into markdown
            return
        }
        let node = CMNode(type: .text)
        try! node.setLiteral(string)
        try! node.insertIntoTree(asLastChildOf: currentParent) // XXX need error checking on this
    }
//
//    /// CDATA.  Used for html, stuff that looks like html, each line of a code block.
//    /// Headings and HR in markdown end up as HTML rather than tags.
//    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
//        guard let cdataString = String(data: CDATABlock, encoding: .utf8) else {
//            errorHandler?("Can't decode CDATA to UTF8 \(CDATABlock as NSData)")
//            return
//        }
//
//        if inside.contains(.codeListing) {
//            output += whitespace.prefix() + cdataString + "\n"
//        } else if let imageLink = parseImageLink(html: cdataString) {
//            output += imageLink
//        } else if cdataString == "<hr/>" {
//            output += "---"
//        } else if let heading = parseHeading(html: cdataString) {
//            output += heading
//        } else {
//            output += cdataString
//        }
//    }
//
//    /// Painful <img> roundtripping.  Relies on SourceKit's attrib ordering.
//    static let imgTagRegex: NSRegularExpression =
//        try! NSRegularExpression(pattern: "<img src=\"(.*?)\"(?: title=\"(.*?)\")?(?: alt=\"(.*?)\")?/>")
//
//    private func parseImageLink(html: String) -> String? {
//        guard let matchedStrings = XMLToMarkdown.imgTagRegex.matches(in: html) else {
//            return nil
//        }
//
//        var imgMarkdown = "!["
//
//        if let altText = matchedStrings[3] {
//            imgMarkdown += altText
//        }
//
//        imgMarkdown += "](\(matchedStrings[1]!)"
//
//        if let title = matchedStrings[2] {
//            imgMarkdown += " \"\(title)\""
//        }
//
//        imgMarkdown += ")"
//
//        return imgMarkdown
//    }
//
//    /// Headings
//    private static let headingTagRegex: NSRegularExpression =
//        try! NSRegularExpression(pattern: "<(/)?h(\\d)>")
//
//    private func parseHeading(html: String) -> String? {
//        guard let matchedStrings = XMLToMarkdown.headingTagRegex.matches(in: html),
//              let headingLevelString = matchedStrings[2],
//              let headingLevel = Int(headingLevelString) else {
//            return nil
//        }
//
//        // no newline after this html, kind of becomes inline...
//        inside.insert(.htmlHeading)
//
//        if matchedStrings[1] != nil {
//            return ""
//        } else {
//            return String(repeating: "#", count: headingLevel) + " "
//        }
//    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        logWarning("XML parse error handling inherited doc comment: \(parseError).")
    }
}
