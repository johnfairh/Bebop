//
//  GatherXMLDocs.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif // rude comment
import Maaku

/// Wackiness to turn an XML doc comment back into markdown for uniform processing by the rest
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
/// Error handling: we use try! for CM APIs that we know will work, and try? for those that depend
/// on a sensible XML structure - if things go wrong we should just get incomplete docs out.
///
/// `internal` for unit test.
///
final class XMLDocBuilder: NSObject, XMLParserDelegate {
    typealias StartElementFn = (String, [String : String]) -> Void

    private var startElement: StartElementFn = { _, _ in }

    func setStartElement(to call: @escaping StartElementFn) {
        self.startElement = call
    }

    // State tracking current client request
    typealias ClientDoneFn = (CMNode) -> Void
    private struct Client {
        let root: CMNode
        let done: ClientDoneFn
        func complete() {
            done(root)
        }
    }
    private var request: Client?
    private var startElementActive = false
    private func issueStartElement(_ name: String, attrs: [String : String]) -> Client? {
        precondition(!startElementActive)
        startElementActive = true
        defer { startElementActive = false; request = nil }
        startElement(name, attrs)
        return request
    }

    /// Client call from the `StartElement` callback to actually start building a markdown document
    func startDocument(type: CMNodeType = .document, callback: @escaping ClientDoneFn) {
        precondition(startElementActive)
        precondition(request == nil)
        request = Client(root: CMNode(type: type), done: callback)
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
            throw BBError(.errXmlDocsParse, errStr, xmlParser.lineNumber, xmlParser.columnNumber)
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
            and?()
            self.currentParent = oldCurrentParent
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
            if let client = issueStartElement(elementName, attrs: attributeDict) {
                // can be nested - just pause the current until this one is done
                newParentUntilElementDone(client.root) {
                    client.complete()
                }
            } else {
                nopOnElementDone()
            }
            return
        }

        // 2 - abandon if we're not interested in turning this part
        //     of the document into markdown

        guard let currentParent = currentParent else {
            nopOnElementDone()
            return
        }

        func newParent(type: CMNodeType, tap: ((CMNode) -> Void)? = nil, and: ElementDoneFn? = nil) {
            let node = CMNode(type: type)
            tap?(node)
            try? node.insertIntoTree(asLastChildOf: currentParent)
            newParentUntilElementDone(node, and: and)
        }

        // 3 - build up the markdown tree

        switch element {
        // Simple
        case .emphasis:  newParent(type: .emphasis)
        case .bold:      newParent(type: .strong)
        case .codeVoice: newParent(type: .code)
        case .para:      newParent(type: .paragraph)
        case .item:      newParent(type: .item)

        // Parameterized
        case .link:
            newParent(type: .link, tap: { node in
                try! node.setLinkDestination(attributeDict["href"] ?? "")
            })

        case .listBullet, .listNumber:
            newParent(type: .list, tap: { node in
                if element == .listNumber {
                    try! node.setListType(.ordered)
                    try! node.setListStartingNumber(1)
                }
                try! node.setListTight(true)
            })

        // Compound
        case .codeListing:
            precondition(codeBlockContent.isEmpty)
            newParent(type: .codeBlock, tap: { node in
                if let language = attributeDict["language"] {
                    try! node.setFencedCodeInfo(language)
                }
            }, and: {
                // All the content of the block goes into this node's literal,
                // but in XML there is an overengineered hierarchy going on that
                // we collect using parser-global state.
                try! self.currentParent?.setLiteral(self.codeBlockContent)
                self.codeBlockContent = ""
            })

        case .zCodeLineNumbered:
            // The line content is optional and comes in thru CDATA.
            // Again, it's optional: we have to do the accumulate here because
            // the CDATA won't get called for blank lines.
            precondition(codeBlockCurrentLine.isEmpty)
            doOnElementDone {
                self.codeBlockContent += self.codeBlockCurrentLine + "\n"
                self.codeBlockCurrentLine = ""
            }

        // Complicated
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
        }
    }

    /// End of element - just process whatever was saved when the element opened.
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        elementDone()
    }

    /// Some text to associate with the current node.
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
            try? node.insertIntoTree(asLastChildOf: currentParent)
        }
    }

    /// CDATA.  Used for html, doc elements that are 'too complex to express in XML', each line of a code block.
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let currentParent = currentParent,
            let cdataString = String(data: CDATABlock, encoding: .utf8) else {
            // Not turning this part of the doc into markdown
            return
        }

        if currentParent.type == .codeBlock {
            precondition(codeBlockCurrentLine.isEmpty)
            codeBlockCurrentLine = cdataString
            return
        }

        var newNode: CMNode? = nil

        if rawHTMLState.isIdle {
            // CDATA in some random element?
            newNode = CMNode(type: .text)
            try! newNode?.setLiteral(cdataString)
        } else if cdataString == "<hr/>" {
            newNode = CMNode(type: .thematicBreak)
        } else if cdataString == "<br/>" {
            newNode = CMNode(type: .lineBreak)
        } else if let match = cdataString.re_match(#"^<h(\d)>$"#) {
            newNode = CMNode(type: .heading)
            try! newNode?.setHeadingLevel(Int32(match[1])!)
            rawHTMLState = .startElement(newNode!)
        } else if cdataString.re_isMatch(#"^</h\d>$"#) {
            rawHTMLState = .endElement
        } else if let match = cdataString.re_match(#"<img src="(.*?)"(?: title="(.*?)")?(?: alt="(.*?)")?/>"#) {
            // side-eye at commonmark this time - link alt text is a child markdown tree rendered as plaintext...
            newNode = CMNode(type: .image)
            try! newNode?.setLinkDestination(match[1])
            try! newNode?.setLinkTitle(match[2])
            let altTextNode = CMNode(type: .text)
            try! altTextNode.setLiteral(match[3])
            try! altTextNode.insertIntoTree(asFirstChildOf: newNode!)
        } else {
            newNode = CMNode(type: .htmlBlock) // sure
            try! newNode?.setLiteral(cdataString)
        }

        try? newNode?.insertIntoTree(asLastChildOf: currentParent)
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // don't do anything, will pick it up from entrypoint.
    }
}

// MARK: XMLDeclarationBuilder

/// This layer 'understands' the XML document-like things that exist in a doc comment.
/// For whatever reason, callouts can't occur except in the 'discussion' element -- swift
/// erases the bullet items, usually leaving spurious empty lists that crash Xcode quick help, gj.
///
/// LocalizationKey disappears somewhere.  Sadface.  I blame DocComment.cpp.
///
/// Not going to support the ClosureParameter nested empire, Xcode will surely never
/// support it and what it implies.  Easy enough to invoke recursively though.
///
/// `internal` for unit test.
final class XMLDeclarationBuilder {
    private(set) var abstract: CMNode?
    private(set) var discussion: CMNode?
    struct Callout {
        let title: String
        let content: CMNode
    }
    private(set) var callouts = [Callout]()
    private(set) var `throws`: CMNode?
    private(set) var returns: CMNode?
    struct Param {
        let name: CMNode
        let description: CMNode
    }
    private(set) var parameters = [Param]()

    private let builder = XMLDocBuilder()

    private func reset() {
        abstract = nil
        discussion = nil
        callouts = []
        `throws` = nil
        returns = nil
        parameters = []
    }

    /// Decompose a `CommentParts` XML element.
    func parseCommentParts(xml: String) throws {
        reset()

        var inParam = false
        var paramName: CMNode?

        func startParam() {
            inParam = true
            paramName = nil
        }

        func endParam(description: CMNode) {
            precondition(inParam)
            if let name = paramName {
                parameters.append(Param(name: name, description: description))
            }
            inParam = false
        }

        func makeCallout(title: String) {
            builder.startDocument(type: .item) { node in
                if !node.isInheritedDocCompilerNote {
                    self.callouts.append(Callout(title: title, content: node))
                }
            }
        }

        builder.setStartElement() { [unowned self] ele, _ in
            switch ele {
            case "Abstract":
                self.builder.startDocument {
                    self.abstract = $0
                }

            case "ThrowsDiscussion":
                self.builder.startDocument {
                    self.throws = $0
                }

            case "ResultDiscussion":
                self.builder.startDocument {
                    self.returns = $0
                }

            case "Parameter":
                startParam()

            case "Name":
                if inParam {
                    self.builder.startDocument(type: .paragraph) {
                        paramName = $0
                    }
                }

            case "Discussion":
                self.builder.startDocument {
                    if inParam {
                        endParam(description: $0)
                    } else {
                        self.discussion = $0
                    }
                }

            case "Parameters", "Direction", "CommentParts":
                // ignore entirely
                break;

            default:
                makeCallout(title: ele.lowercased())
            }
        }

        try builder.parse(xml: xml)
    }

    /// Rewind the accumulated callouts into an equivalent markdown list
    var calloutsList: CMNode? {
        guard !callouts.isEmpty else {
            return nil
        }

        let listNode = CMNode(type: .list)
        try! listNode.setListType(.unordered)
        callouts.forEach { callout in
            let titleNode = CMNode(type: .text)
            try! titleNode.setLiteral(callout.title + ": ")

            if let child = callout.content.firstChild,
                child.type == .paragraph {
                // already text there, just push our title in first
                try! titleNode.insertIntoTree(asFirstChildOf: child)
            } else {
                // Nothing in the callout, or something first that is not para,
                // so insert a para with the text.
                let paraNode = CMNode(type: .paragraph)
                try! titleNode.insertIntoTree(asFirstChildOf: paraNode)
                try! paraNode.insertIntoTree(asFirstChildOf: callout.content)
            }
            try! callout.content.insertIntoTree(asLastChildOf: listNode)
        }
        return listNode
    }

    /// Bodge everything into the `FlatDefDocs` format.
    /// 'shortform' is without discussion -- default format for inherited docs.
    func flatDefDocs(source: DefDocSource, shortForm: Bool) -> FlatDefDocs {
        let mds = [discussion?.renderMarkdown().value, calloutsList?.renderMarkdown().value]
        let fullDiscussion = mds.compactMap { $0 }.joined(separator: "\n\n")
        return FlatDefDocs(abstract: abstract?.renderMarkdown(),
                           discussion: (shortForm || fullDiscussion.isEmpty) ? nil : Markdown(fullDiscussion),
                           throws: `throws`?.renderMarkdown(),
                           returns: returns?.renderMarkdown(),
                           parameters: parameters.map {
                               FlatDefDocs.Param(name: $0.name.renderPlainText(),
                                                 description: $0.description.renderMarkdown())
                           },
                           source: source)
    }
}

// MARK: API

enum XMLDocComment {
    /// Try to pull a broken-down declaration doc comment out of sourcekit `full_as_xml`.
    static func parse(xml: String, source: DefDocSource, shortForm: Bool) -> FlatDefDocs? {
        guard let parts = xml.re_match("<CommentParts>.*</CommentParts>")?[0] else {
            return nil
        }
        let builder = XMLDeclarationBuilder()
        do {
            try builder.parseCommentParts(xml: parts)
            let docs = builder.flatDefDocs(source: source, shortForm: shortForm)
            Stats.inc(.gatherXMLDocCommentsParsed)
            return docs.isEmpty ? nil : docs
        } catch {
            logWarning(.wrnXmlDocsParse, xml, error)
            Stats.inc(.gatherXMLDocCommentsFailed)
        }
        return nil
    }
}

extension CMNode {
    /// Spot the 'helpful' note the compiler generates in some scenarios
    var isInheritedDocCompilerNote: Bool {
        guard let paraChild = firstChild,
              paraChild.type == .paragraph,
              let textChild = paraChild.firstChild,
              textChild.type == .text,
              let text = textChild.literal else {
            return false
        }
        return text.hasPrefix("This documentation comment was inherited from")
    }
}
