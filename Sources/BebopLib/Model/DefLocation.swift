//
//  DefLocation.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// Where a definition was written
public struct DefLocation: Encodable, CustomStringConvertible, Comparable {
    /// Name of the module the definition belongs to.  If the definition is an extension of
    /// a type from a different module then this is the extension's module not the type's.
    public let moduleName: String
    /// Gather pass through the module
    public let passIndex: Int
    /// Full pathname of the definition's source file.  Nil only after some kind of binary gather.
    public let filePathname: String?
    /// First line in the file.  Nil if we don't know it.  Line numbers start at 1.
    public let firstLine: Int?
    /// Last line in the file of the definition.  Can be same as `firstLine`.
    public let lastLine: Int?

    public var description: String {
        let file = filePathname ?? "(??)"
        let from = firstLine ?? 0
        let to = lastLine ?? 0
        return "[\(moduleName):\(passIndex) \(file) ll\(from)-\(to)]"
    }

    /// Comparable.  Bit of a crapshoot in general but reasonable for normal cases.
    public static func < (lhs: DefLocation, rhs: DefLocation) -> Bool {
        if lhs.filePathname == rhs.filePathname {
            return (lhs.firstLine ?? 0) < (rhs.firstLine ?? 0)
        }
        return (lhs.filePathname ?? "") < (rhs.filePathname ?? "")
    }
}
