//
//  DeclPrinter.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SwiftFormat
import SwiftSyntax // DiagnosticEngine!
import SwiftFormatConfiguration

/// Feels awfully luxurious to pull SwiftFormat in just for this, but doing even an OK job
/// manually line-breaking declarations is more work than I want to do.
///
/// namespace.
enum DeclPrinter {
    private struct SwiftFormatWrapper: DiagnosticConsumer {
        private let configuration: Configuration
        private var formatter: SwiftFormatter!

        init() {
            var config = Configuration()
            config.lineLength = 80
            config.tabWidth = 4
            config.indentation = .spaces(4)
            self.configuration = config

            let engine = DiagnosticEngine()
            self.formatter = nil
            engine.addConsumer(self)
            formatter = SwiftFormatter(configuration: configuration,
                                       diagnosticEngine: engine)
        }

        func format(swift: String) -> String {
            do {
                var formatted = ""
                try formatter.format(source: swift, assumingFileURL: nil, to: &formatted)
                return formatted.trimmingTrailingCharacters(in: .whitespacesAndNewlines)
            } catch {
                logDebug("SwiftFormat error thrown: \(error)")
            }
            return swift
        }

        func handle(_ diagnostic: Diagnostic) {
            logDebug("SwiftFormat: \(diagnostic.message.text)")
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

    /// Format a Swift variable declaration
    /// Hide the { get set } thing from SwiftFormat
    static func formatVar(swift: String) -> String {
        guard let matches = swift.re_match(#"^(.*?)( \{.*?\})?$"#) else {
            return swift
        }
        return shared.format(swift: matches[1]) + matches[2]
    }

    /// Format a Swift structural type declaration
    /// Stick in some empty braces to keep SwiftFormat happy
    static func formatStructural(swift: String) -> String {
        let formatted = shared.format(swift: swift + "{}")
        return formatted.re_sub(#"\s+\{\s*\}$"#, with: "")
    }
}
