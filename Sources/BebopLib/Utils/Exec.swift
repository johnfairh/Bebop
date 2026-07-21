//
//  Exec.swift
//  TMLMisc -> SourceKittenFramework -> BebopLib
//
//  Copyright © 2019 SourceKitten. All rights reserved.
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

import Subprocess

/// Namespace for utilities to execute a child process.
enum Exec {
    /// How to handle stderr output from the child process.
    enum Stderr {
        /// Treat stderr same as parent process.
        case inherit
        /// Send stderr to /dev/null.
        case discard
        /// Merge stderr with stdout.
        case merge
    }

    /// The result of running the child process.
    struct Results {
        /// The command that was run
        let command: String
        /// Its arguments
        let arguments: [String]
        /// The process's exit status.
        let terminationStatus: Int32
        /// The data from stdout and optionally stderr with whitespace trimmed.
        /// `nil` for the empty string
        let string: String?
        /// The `data` reinterpreted as a string but intercepted to `nil` if the command actually failed
        var successString: String? {
            guard terminationStatus == 0 else {
                return nil
            }
            return string
        }
        /// Some text explaining a failure
        var failureReport: String {
            var report = """
            Command failed: \(command)
            Arguments: \(arguments)
            Exit status: \(terminationStatus)
            """
            if let output = string {
                report += ", output:\n\(output)"
            }
            return report
        }
    }

    /**
    Run a command with arguments and return its output and exit status.

    - parameter command: Absolute path of the command to run.
    - parameter arguments: Arguments to pass to the command.
    - parameter currentDirectory: Current directory for the command.  By default
                                  the parent process's current directory.
    - parameter stderr: What to do with stderr output from the command.  By default
                        whatever the parent process does.
    */
    static func run(_ command: String,
                    _ arguments: String...,
                    currentDirectory: String = FileManager.default.currentDirectoryPath,
                    stderr: Stderr = .inherit) -> Results {
        switch stderr {
        case .discard:
            runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .discarded)
        case .inherit:
            runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .currentStandardError)
        case .merge:
            runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .combinedWithOutput)
        }
    }

    /**
     Run a command with arguments and return its output and exit status.

     - parameter command: Absolute path of the command to run.
     - parameter arguments: Arguments to pass to the command.
     - parameter currentDirectory: Current directory for the command.  By default
                                   the parent process's current directory.
     - parameter stderr: What to do with stderr output from the command.  By default
                         whatever the parent process does.
     */
     static func run(_ command: String,
                     _ arguments: [String] = [],
                     currentDirectory: String = FileManager.default.currentDirectoryPath,
                     stderr: Stderr = .inherit) -> Results {
         switch stderr {
         case .discard:
             runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .discarded)
         case .inherit:
             runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .currentStandardError)
         case .merge:
             runSubprocess(command, arguments, currentDirectory: currentDirectory, stderr: .combinedWithOutput)
         }
    }

    private final class AState: @unchecked Sendable {
        var results: Results?
        init() {
            results = nil
        }
    }

    private static func runSubprocess<StdErr: Subprocess.ErrorOutputProtocol>(
        _ command: String,
        _ arguments: [String] = [],
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        stderr: StdErr = .currentStandardError) -> Results {

        let state = AState()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                let result = try await Subprocess.run(
                    .path(.init(command)),
                    arguments: .init(arguments),
                    workingDirectory: .init(currentDirectory),
                    output: .string(limit: 1000000), /* what the fuck */
                    error: stderr
                )

                switch result.terminationStatus {
                case .exited(let terminationStatus):
                    let strResult = result.standardOutput.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    state.results = Results(command: command,
                                            arguments: arguments,
                                            terminationStatus: terminationStatus,
                                            string: strResult.flatMap { $0.isEmpty ? nil : $0 })
                case .signaled(let signal):
                    logError("Dodgy subprocess exited-on-signal: \(command) \(signal)")
                    state.results = Results(command: command, arguments: arguments, terminationStatus: -2, string: nil)
                }
            } catch {
                logError("Dodgy Subprocess error: \(command) \(error)")
                state.results = Results(command: command, arguments: arguments, terminationStatus: -1, string: nil)
            }
            semaphore.signal()
        }
        semaphore.wait()

        return state.results!
   }
}
