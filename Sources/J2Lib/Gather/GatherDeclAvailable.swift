//
//  GatherDeclAvailable.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SwiftSyntax

//
// This is a horror-show unfortunately -- @available can express so many different
// things in so many different ways, brute-force here really.  SwiftSyntax means
// we don't have to lex the text and worry about raw strings etc. but there's no
// getting away from parsing the resulting arguments.  Would help some to get the
// actual compiler decode from doc-info into cursorinfo.
//

// First some types to categorize the @available arguments, which can occur
// in practically any order.

private enum AvailKeyword: String {
    case unavailable
    case introduced
    case deprecated
    case obsoleted
    case message
    case renamed
}

private enum AvailArg {
    case star
    case token(String)
    case doubleToken(String, String)
    case keyword(AvailKeyword, String?)
}

// Now a SwiftSyntax visitor to lex the actual text and produce `AvailArgs`

private class FunctionPiecesVisitor: SyntaxVisitor {
    var args: [AvailArg] = []

    /// Messy SwiftSyntax here --- this is for ALL types of arg, we need to spot the ones where there is just one token
    /// underneath and figure out what it is.
    func visit(_ node: AvailabilityArgumentSyntax) -> SyntaxVisitorContinueKind {
        if node.entry.isToken, let tok = node.entry.firstToken {
            if tok.text == "*" {
                args.append(.star)
            } else if let kw = AvailKeyword(rawValue: tok.text) {
                /// Raw 'deprecated', love you guys...
                args.append(.keyword(kw, nil))
            } else {
                args.append(.token(tok.text))
            }
            return .skipChildren
        }
        return .visitChildren
    }

    static let qStringTrimSet = CharacterSet(charactersIn: " \"")

    /// For a: "b" --- assume we know all the a's and don't want quotes around the b
    func visit(_ node: AvailabilityLabeledArgumentSyntax) -> SyntaxVisitorContinueKind {
        let tok1 = node.label.withoutTrailingTrivia().description
        let tok2 = node.value.description.trimmingCharacters(in: Self.qStringTrimSet)
        if let kw = AvailKeyword(rawValue: tok1) {
            args.append(.keyword(kw, tok2))
        }
        return .skipChildren
    }

    /// For "a b"
    func visit(_ node: AvailabilityVersionRestrictionSyntax) -> SyntaxVisitorContinueKind {
        let tok1 = node.platform.withoutTrailingTrivia().description
        let tok2 = node.version.description.trimmingTrailingCharacters(in: .whitespaces)
        args.append(.doubleToken(tok1, tok2))
        return .skipChildren
    }
}

// An interface to wrap that up

private extension String {
    func parseAvailable() -> [AvailArg] {
        var visitor = FunctionPiecesVisitor()
        guard let syntax = try? SyntaxParser.parse(source: self) else {
            return []
        }
        syntax.walk(&visitor)
        return visitor.args
    }
}

// And finally some code to actually interpret the attributes and massage
// them into the formats we want

extension SwiftDeclarationBuilder {
    /// Parse the @available attributes and update members 'deprecations' and 'availability'
    func parse(availables: [String]) {
        // reset calculated availability
        availability = []
        availables.forEach {
            let args = $0.parseAvailable()
            guard args.count > 0 else {
                logDebug("Failed to parse @available: '\($0)'.")
                return
            }
            switch args[0] {
            case .token(let platform):
                parseAvailable(platform: platform, args: args.dropFirst())
            case .star:
                parseDeprecation(args: args.dropFirst())
            default:
                parseIntroduced(args: args)
            }
        }
    }

    /// @available form #1 - lots of facts about one platform.
    /// Generate up to one availability clause and one deprecation statement.
    fileprivate func parseAvailable(platform: String, args: ArraySlice<AvailArg>) {
        var introduced: String?
        var deprecated: String?
        var isDeprecated: Bool = false
        var obsoleted: String?
        var message: String?
        var renamed: String?
        var isUnavailable: Bool = false

        args.forEach {
            if case let .keyword(kw, arg) = $0 {
                switch kw {
                case .introduced:
                    introduced = arg
                case .deprecated:
                    deprecated = arg
                    isDeprecated = true
                case .obsoleted:
                    obsoleted = arg
                case .message:
                    message = arg
                case .renamed:
                    renamed = arg
                case .unavailable:
                    isUnavailable = true
                }
            }
        }

        if let introduced = introduced {
            if let obsoleted = obsoleted {
                availability.append("\(platform) \(introduced)-\(obsoleted)")
            } else {
                availability.append("\(platform) \(introduced)+")
            }
        } else if let obsoleted = obsoleted {
            availability.append("\(platform) ?-\(obsoleted)")
        }

        var depText = Localized<String>()
        if let obsoleted = obsoleted {
            depText = .localizedOutput(.platObsoletedVer, platform, obsoleted)
        }
        else if isDeprecated {
            if let deprecated = deprecated {
                depText = .localizedOutput(.platDeprecatedVer, platform, deprecated)
            } else {
                depText = .localizedOutput(.platDeprecated, platform)
            }
        }
        if isUnavailable {
            depText = .localizedOutput(.platUnavailable, platform)
        }
        if let message = message {
            depText = depText.append(" \(message).")
        }
        if let renamed = renamed {
            depText = depText.append(.localizedOutput(.renamedTo, renamed))
        }
        if !depText.isEmpty {
            deprecations.append(depText)
        }
    }

    /// @available form #2 - some facts about all platforms.
    /// Version numbers can't apply here so this means up to one deprecation statement.
    fileprivate func parseDeprecation(args: ArraySlice<AvailArg>) {
        var message: String?
        var renamed: String?
        var isUnavailable: Bool = false
        var isDeprecated: Bool = false

        args.forEach {
            if case let .keyword(kw, arg) = $0 {
                switch kw {
                case .deprecated:
                    isDeprecated = true
                case .unavailable:
                    isUnavailable = true
                case .message:
                    message = arg
                case .renamed:
                    renamed = arg
                default:
                    break
                }
            }
        }

        var text = Localized<String>()
        if isUnavailable {
            text = .localizedOutput(.unavailable)
        } else if isDeprecated {
            text = .localizedOutput(.deprecated)
        }
        if let message = message {
            text = text.append(" \(message).")
        }
        if let renamed = renamed {
            text = text.append(.localizedOutput(.renamedTo, renamed))
        }
        if !text.isEmpty {
            deprecations.append(text)
        }
    }

    /// @available form #3 - introductions on multiple platforms
    fileprivate func parseIntroduced(args: Array<AvailArg>) {
        args.forEach {
            if case let .doubleToken(platform, version) = $0 {
                availability.append("\(platform) \(version)+")
            }
        }
    }
}
