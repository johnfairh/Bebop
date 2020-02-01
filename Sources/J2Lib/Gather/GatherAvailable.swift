//
//  GatherAvailable.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

//
// This is a horror-show unfortunately -- @available can express so many different
// things in so many different ways, brute-force here really.  SwiftSyntax doesn't
// help much, not enough resolution - ideal would be to get the actual compiler
// decode from doc-info into cursorinfo.
//

// XXX localization - including deprecation messages....

extension SwiftDeclarationBuilder {
    /// Parse the @available attributes and update members 'deprecations' and 'availability'
    func parse(availables: [String]) {
        availables.forEach {
            let args = $0.parseAvailable()
            guard args.count > 0 else {
                logWarning("Failed to parse @available: '$0'.")
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
                availability.append("\(platform) \(introduced)")
            }
        } else if let obsoleted = obsoleted {
            availability.append("\(platform) ?-\(obsoleted)")
        }

        var depText = ""
        if let obsoleted = obsoleted {
            depText = "\(platform) - obsoleted in \(obsoleted)."
        }
        else if isDeprecated {
            depText = "\(platform) - deprecated"
            if let deprecated = deprecated {
                depText += " in \(deprecated)."
            } else {
                depText += "."
            }
        }
        if isUnavailable {
            depText = "\(platform) - unavailable."
        }
        if let message = message {
            depText += " \(message)."
        }
        if let renamed = renamed {
            depText += " Renamed: `\(renamed)`."
        }
        if depText != "" {
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

        var text = ""
        if isUnavailable {
            text = "Unavailable."
        } else if isDeprecated {
            text = "Deprecated."
        }
        if let message = message {
            text += " \(message)."
        }
        if let renamed = renamed {
            text += " Renamed: `\(renamed)`."
        }
        if text != "" {
            deprecations.append(text)
        }
    }

    /// @available form #3 - introductions on multiple platforms
    fileprivate func parseIntroduced(args: Array<AvailArg>) {
        args.forEach {
            if case let .doubleToken(platform, version) = $0 {
                availability.append("\(platform) \(version)")
            }
        }
    }

}

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

// This isn't incredibly robust but should just stop rather
// than crash in the presence of bad syntax, exotic whitespace,
// or bold usage of raw strings.
private extension String {
    mutating func eatTrivia() {
        while let first = first {
            guard first == " " || first == ":" else {
                return
            }
            removeFirst()
        }
    }

    mutating func eatIntro() {
        precondition(hasPrefix("@available"))
        removeFirst("@available".count)
        eatTrivia()
        if first == "(" {
            removeFirst()
            eatTrivia()
        }
    }

    mutating func takeQuotedString() -> String {
        precondition(first == "\"")
        removeFirst()
        var qStr = ""
        while !isEmpty {
            let next = removeFirst()
            if next == "\"" {
                break
            }
            if next == "\\" {
                qStr.append(removeFirst())
            } else {
                qStr.append(next)
            }
        }
        eatTrivia()
        return qStr
    }

    mutating func takeToken() -> String {
        precondition(first != " " && first != "\"")
        var tok = ""
        while let first = first {
            guard !" ,):".contains(first) else {
                break
            }
            tok.append(removeFirst())
        }
        return tok
    }

    mutating func takeArg() -> AvailArg? {
        guard let firstC = first, firstC != ")" else {
            return nil
        }
        let arg: AvailArg?
        if firstC == "*" {
            removeFirst()
            arg = .star
        } else {
            let tok1 = takeToken()
            eatTrivia()
            let nextC = first
            if let kw = AvailKeyword(rawValue: tok1) {
                let param: String?
                if nextC == "\"" {
                    param = takeQuotedString()
                } else if let nextC = nextC, !",)".contains(nextC) {
                    param = takeToken()
                } else {
                    param = nil
                }
                arg = .keyword(kw, param)
            } else {
                if let nextC = nextC, !",)".contains(nextC) {
                    arg = .doubleToken(tok1, takeToken())
                } else {
                    arg = .token(tok1)
                }
            }
        }
        eatTrivia()
        if first == "," {
            removeFirst()
            eatTrivia()
        }
        return arg
    }

    func parseAvailable() -> [AvailArg] {
        var copy = self
        copy.eatIntro()
        var args = [AvailArg]()
        while let arg = copy.takeArg() {
            args.append(arg)
        }
        if let lastArg = args.last,
            case .star = lastArg {
            args.removeLast()
        }
        return args
    }
}
