//
//  FileManager.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//
import Foundation

extension FileManager {
    /// Create a new empty temporary directory.  Caller must delete.
    func createTemporaryDirectory(inDirectory directory: URL? = nil, name: String? = nil) throws -> URL {
        let directoryName = name ?? UUID().uuidString
        let parentDirectoryURL = directory ?? temporaryDirectory
        let directoryURL = parentDirectoryURL.appendingPathComponent(directoryName)
        try createDirectory(at: directoryURL, withIntermediateDirectories: false)
        return directoryURL
    }

    /// Get a new temporary filename.  Caller must delete.
    func temporaryFileURL(inDirectory directory: URL? = nil) -> URL {
        let filename     = UUID().uuidString
        let directoryURL = directory ?? temporaryDirectory
        return directoryURL.appendingPathComponent(filename)
    }

    /// A file URL for the current directory
    var currentDirectory: URL {
        URL(fileURLWithPath: currentDirectoryPath)
    }
}

extension FileManager {
    static func preservingCurrentDirectory<T>(_ code: () throws -> T) rethrows -> T {
        let fileManager = FileManager.default
        let cwd = fileManager.currentDirectoryPath
        defer {
            let rc = fileManager.changeCurrentDirectoryPath(cwd)
            if !rc {
                // this is really bad, original directory deleted?  Struggle on.
                logWarning(.wrnPathNoChdir, cwd)
            }
        }
        return try code()
    }
}

extension URL {
    /// Execute some code with this file directory URL as the current directory, restoring current directory afterwards.
    ///
    /// I didn't mean to borrow this from Ruby -- wrote 90% of it with pieces then realized what the pattern was...
    public func withCurrentDirectory<T>(code: () throws -> T) throws -> T {
        try checkIsDirectory()
        return try FileManager.preservingCurrentDirectory {
            _ = FileManager.default.changeCurrentDirectoryPath(path)
            return try code()
        }
    }
}

/// An RAAI  type to manage a temporary directory and files
final class TemporaryDirectory {
    let directoryURL: URL
    /// Set true to keep the directory after this `TemporaryDirectory` object expires
    var keepDirectory = false

    /// Create a new temporary directory somewhere in the filesystem that by default will be deleted
    /// along with its contents when the object goes out of scope.
    init() throws {
        directoryURL = try FileManager.default.createTemporaryDirectory()
    }

    /// Wrap an existing directory that, by default, will not be deleted when this object goes out of scope.
    init(url: URL) {
        directoryURL = url
        keepDirectory = true
    }

    deinit {
        if !keepDirectory {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    /// Get a path for a temp file in this object's directory.  File doesn't exist, directory does.
    func createFile(name: String? = nil) throws -> URL {
        if let name = name {
            return directoryURL.appendingPathComponent(name)
        }
        return FileManager.default.temporaryFileURL(inDirectory: directoryURL)
    }

    /// Get a path for a subdirectory in this object's directory.
    /// The new `TemporaryDirectory` is not auto-delete by default.
    func createDirectory(name: String? = nil) throws -> TemporaryDirectory {
        let url = try FileManager.default.createTemporaryDirectory(inDirectory: directoryURL, name: name)
        return TemporaryDirectory(url: url)
    }

    /// Run some code in new temporary directory, cleaning up afterwards
    static func withNew<T>(_ code: () throws -> T) throws -> T {
        try withExtendedLifetime(TemporaryDirectory()) { tmpDir in
            try tmpDir.directoryURL.withCurrentDirectory(code: code)
        }
    }
}

extension FileManager {
    /// Copy a file overwriting if necessary
    public func forceCopyItem(at: URL, to: URL) throws {
        if fileExists(atPath: to.path) {
            try removeItem(at: to)
        }
        try copyItem(at: at, to: to)
    }

    /// Beware this overwrites rather than merging copied subdirectories
    public func forceCopyContents(of srcDirURL: URL, to dstDirURL: URL) throws {
        try srcDirURL.filesMatching(.all).forEach { srcFileURL in
            let dstFileURL = dstDirURL.appendingPathComponent(srcFileURL.lastPathComponent)
            try forceCopyItem(at: srcFileURL, to: dstFileURL)
        }
    }
}

extension String {
    /// Write contents to a file, creating directories along the way if necessary
    func write(to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try write(to: url, atomically: true, encoding: .utf8)
    }
}

extension String {
    /// For a canonical filepath, how many directories of nesting are there?
    var directoryNestingDepth: Int {
        reduce(0) { $0 + ($1 == "/" ? 1 : 0) }
    }
}

extension URL {
    /// This is probably wrong in lots of ways
    func asRelativePath(from base: URL) -> String {
        let dstPathElems = path.split(separator: "/")
        let srcPathElems = base.path.split(separator: "/")

        var commonCount = 0
        for e in zip(dstPathElems, srcPathElems) {
            if e.0 != e.1 {
                break
            }
            commonCount += 1
        }

        return String(repeating: "../", count: srcPathElems.count - commonCount) +
            dstPathElems.dropFirst(commonCount).joined(separator: "/")
    }
}
