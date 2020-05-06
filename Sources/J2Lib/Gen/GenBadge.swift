//
//  GenBadge.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Generate shields.io-style badge.
///
/// Totally 'reused' from segiddens' jazzy version.
///
/// Incomplete - not sure how best to localize this, too much arithmetic tied to the width of the 'documentation'
/// text.  Stick the whole thing in a resource?  Still too much arithmetic.  Leaving it for now: never really been
/// documented properly, leave it that way.
///
final class GenBadge: Configurable {
    init(config: Config) {
        config.register(self)
    }

    /// Create the badge for the current coverage localized appropriately
    func write(docRootURL: URL, languageTag: String) throws {
        logDebug("GenBadge: write")
        try badgeXML.write(to: docRootURL.appendingPathComponent("badge.svg"))
    }

    private(set) var _badgeXML: String?

    private var badgeXML: String {
        if let xml = _badgeXML {
            return xml
        }

        let coverage = Stats.coverage
        let coverageLength = String(coverage).count + 1
        let percentStringLength = coverageLength * 80 + 10
        let percentStringOffset = coverageLength * 40 + 975
        let width = coverageLength * 8 + 104
        let svg =
            """
            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="\(width)" height="20">
              <linearGradient id="b" x2="0" y2="100%">
                <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
                <stop offset="1" stop-opacity=".1"/>
              </linearGradient>
              <clipPath id="a">
                <rect width="\(width)" height="20" rx="3" fill="#fff"/>
              </clipPath>
              <g clip-path="url(#a)">
                <path fill="#555" d="M0 0h93v20H0z"/>
                <path fill="#\(colorFor(coverage: coverage))" d="M93 0h\(percentStringLength / 10 + 10)v20H93z"/>
                <path fill="url(#b)" d="M0 0h\(width)v20H0z"/>
              </g>
              <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="110">
                <text x="475" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="830">
                  documentation
                </text>
                <text x="475" y="140" transform="scale(.1)" textLength="830">
                  documentation
                </text>
                <text x="\(percentStringOffset)" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="\(percentStringLength)">
                  \(coverage)%
                </text>
                <text x="\(percentStringOffset)" y="140" transform="scale(.1)" textLength="\(percentStringLength)">
                  \(coverage)%
                </text>
              </g>
            </svg>
           """
        _badgeXML = svg
        return svg
    }

    /// The appropriate color for the provided percentage
    private func colorFor(coverage: Int) -> String {
        if coverage < 10 {
            return "e05d44" // red
        } else if coverage < 30 {
            return "fe7d37" // orange
        } else if coverage < 60 {
            return "dfb317" // yellow
        } else if coverage < 85 {
            return "a4a61d" // yellowgreen
        } else if coverage < 90 {
            return "97CA00" // green
        }
        return "4c1" // brightgreen
    }
}
