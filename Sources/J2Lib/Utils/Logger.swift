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

        logHandler(messagePrefix(level) + message(), diagnosticLevels.contains(level))
    }

    /// Logger back-end, actually do something with a message.
    public var logHandler: (String, _ isDiagnostic: Bool) -> Void = { m, d in
        if d {
            print(m, to: &StdStream.stderr)
        } else {
            print(m, to: &StdStream.stdout)
        }
    }

    /// Initialize a new `Logger` with default settings
    public init() {}
}

// MARK: Globals

// For ease, avoiding injecting an instance everywhere, will try module-internal globals.
internal extension Logger {
    static var shared = Logger()
}

/// Log a debug-level message
internal func logDebug(_ message: @autoclosure () -> String) {
    Logger.shared.log(.debug, message())
}

/// Log an info-level message
internal func logInfo(_ message: @autoclosure () -> String) {
    Logger.shared.log(.info, message())
}

/// Log a warning message
internal func logWarning(_ message: @autoclosure () -> String) {
    Logger.shared.log(.warning, message())
}

/// Log an error message
internal func logError(_ message: @autoclosure () -> String) {
    Logger.shared.log(.error, message())
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
