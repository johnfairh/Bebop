//
//  Logger.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Logging abstraction
///
/// Should switch to swift-log when we let Xcode manage the Package.swift.
public final class Logger {
    /// Categories of log messages
    public enum Level {
        /// Messages about the internal running of the program that may be of interest when debugging
        /// or analyzing timings.  Not necessarily intended for end-users.
        case debug
        /// Messages about normal running of the program intended for end-users to communicate
        /// status and progress.
        case info
        /// Messages about abnormal running of the program intended for end-users.
        /// Warnings indicate that the system has found itself in an unusual situation but
        /// is proceeding anyway as best it can.  The end-user can judge whether the situation
        /// is acceptable or if they need to adjust the environment in some way.
        case warning
        /// Messages about abnormal conditions that make the program unable to continue.
        case error
    }

    /// A set of log levels
    public typealias Levels = Set<Level>

    public static let allLevels = Levels([.debug, .info, .warning, .error])

    /// Quiet logging - just error diagnostics
    public static let quietLevels = Levels([.error])
    /// Regular logging - user info and diagnostics
    public static let normalLevels = Levels([.info, .warning, .error])
    /// Verbose logging - debug info, user info, diagnostics
    public static let verboseLevels = allLevels

    /// The log levels that this logger will propagate
    public var activeLevels: Levels = normalLevels

    /// Diagnostic classification
    public var diagnosticLevels = Levels([.debug, .warning, .error])

    /// Prefix for this logger's  messages
    public var messagePrefix: (Level) -> String = { _ in "" }

    /// Log a message
    public func log(_ level: Level, _ message: @autoclosure () -> String) {
        guard activeLevels.contains(level) else {
            return
        }

        logHandler(messagePrefix(level) + message(),
                   diagnosticLevels.contains(level) ? .diagnostic : .message)
    }

    // Produce some output
    public func output(_ data: String) {
        logHandler(data, .output)
    }

    /// Logger back-end characterization
    public enum LogHandlerLevel {
        /// abnormal status message
        case diagnostic
        /// normal status message
        case message
        /// meaningful program output
        case output
    }

    /// Logger back-end, actually do something with a message.
    public var logHandler: (String, _ level: LogHandlerLevel) -> Void = { m, d in
        switch d {
        case .diagnostic:
            print(m, to: &StdStream.stderr)
        case .message, .output:
            print(m, to: &StdStream.stdout)
        }
    }

    /// Initialize a new `Logger` with default settings
    public init() {}
}

// MARK: Globals

// For ease, avoiding injecting an instance everywhere, will try module-internal globals.
extension Logger {
    static var shared = Logger()
}

/// Log a debug-level message
func logDebug(_ message: @autoclosure () -> String) {
    Logger.shared.log(.debug, message())
}

/// Log an info-level message
func logInfo(_ message: @autoclosure () -> String) {
    Logger.shared.log(.info, message())
}

func logInfo(_ key: L10n.Localizable, _ args: Any...) {
    logInfo(.localized(key, args))
}

/// Log a warning message
func logWarning(_ message: @autoclosure () -> String) {
    Logger.shared.log(.warning, message())
}

func logWarning(_ key: L10n.Localizable, _ args: Any...) {
    logWarning(.localized(key, args))
}

/// Log an error message
func logError(_ message: @autoclosure () -> String) {
    Logger.shared.log(.error, message())
}

/// Make some output
func logOutput(_ data: String) {
    Logger.shared.output(data)
}

// MARK: Std streams

// What a mess!

import Foundation

fileprivate struct StdStream: TextOutputStream {
    let fh: FileHandle
    // This may not even be right, who is flushing or locking what when??
    mutating func write(_ string: String) {
        fh.write(string.data(using: .utf8)!)
    }

    static var stdout = StdStream(fh: .standardOutput)
    static var stderr = StdStream(fh: .standardError)
}
