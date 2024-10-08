//
//  DeclPrinter.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SwiftFormat
import SwiftSyntax // DiagnosticEngine!

/// Feels awfully luxurious to pull SwiftFormat in just for this, but doing even an OK job
/// manually line-breaking declarations is more work than I want to do.
///
/// namespace.
enum DeclPrinter {
    private struct SwiftFormatWrapper: @unchecked Sendable {
        private let configuration: Configuration
        private let formatter: SwiftFormatter

        init() {
            var config = Configuration()
            config.lineLength = 80
            config.tabWidth = 4
            config.indentation = .spaces(4)

            configuration = config
            formatter = SwiftFormatter(configuration: configuration) { finding in
                logDebug("SwiftFormat: \(finding.message)")
            }
        }

        func format(swift: String) -> String {
            do {
                var formatted = ""
                try formatter.format(source: swift, assumingFileURL: nil, selection: .infinite, to: &formatted)
                // swift-format workarounds
                //
                if swift.hasPrefix("case ") {
                    // bizarre space-removal after enum case initialization
                    formatted = formatted.re_sub(#"(?<=\S)= "#, with: " = ")
                }
                return formatted.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
            } catch {
                logDebug("SwiftFormat error thrown: \(error) for '\(swift)'")
            }
            return swift
        }

        func finalize() {
        }
    }

    private static let shared = SwiftFormatWrapper()

    /// Format the Swift code to 80-character width.
    /// Return the original string if anything goes wrong.
    /// Go directly to SwiftFormat - has murky requirements about the content.
    static func format(swift: String) -> String {
        shared.format(swift: swift)
    }

    /// Format a Swift structural type declaration
    /// Stick in some empty braces to keep SwiftFormat happy
    static func formatStructural(swift: String) -> String {
        let formatted = shared.format(swift: swift + " {}")
        return formatted.re_sub(#"\s+\{\s*\}$"#, with: "")
    }
}
