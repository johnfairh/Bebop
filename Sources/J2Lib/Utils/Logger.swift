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
public struct Logger {
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

        /// Is this message a diagnostic (typically, should it go to stderr?)
        var isDiagnostic: Bool {
            self != .info
        }
    }

    /// A set of log levels
    public typealias Levels = Set<Level>

    /// Quiet logging - just error diagnostics
    public static var quietLevels = Levels([.error])
    /// Regular logging - user info and diagnostics
    public static var normalLevels = Levels([.info, .warning, .error])
    /// Verbose logging - debug info, user info, diagnostics
    public static var verboseLevels = Levels([.debug, .info, .warning, .error])

    /// The log levels that this logger will propagate
    public var activeLevels: Levels = normalLevels

    /// A version of `stdout` that can be used to direct a logger's output
    public static let stdout: TextOutputStream = StdStream.stdout
    /// A version of `stderr` that can be used to direct a logger's output
    public static let stderr: TextOutputStream = StdStream.stderr

    /// Stream for the logger's `info` messages
    public var normalStream: TextOutputStream = stdout
    /// Stream for the logger's `debug`, `warning`, `error` messages
    public var diagnosticStream: TextOutputStream = stderr

    /// Prefix for this logger's  messages
    public var messagePrefix: (Level) -> String = { _ in "" }

    /// Log a message
    public func log(_ level: Level, _ message: @autoclosure () -> String) {
        guard activeLevels.contains(level) else {
            return
        }
        var stream = level.isDiagnostic ? diagnosticStream : normalStream
        stream.write("\(messagePrefix(level))\(message())\n")
    }
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
    // This may not even be right, who is flushing what when?  Good grief.
    mutating func write(_ string: String) {
        fh.write(string.data(using: .utf8)!)
    }

    static let stdout = StdStream(fh: .standardOutput)
    static let stderr = StdStream(fh: .standardError)
}
