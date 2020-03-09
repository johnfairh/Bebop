//
//  DefAcl.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Swift definition access control level
public enum DefAcl: String, Comparable, CaseIterable, Encodable {
    case `private`
    case `fileprivate`
    case `internal`
    case `public`
    case `open`

    // Map from Acl to number, higher number = more open
    static let indexMap = [DefAcl : Int](
        uniqueKeysWithValues: DefAcl.allCases.enumerated().map { offs, el in (el, offs) }
    )

    public static func < (lhs: DefAcl, rhs: DefAcl) -> Bool {
        indexMap[lhs]! < indexMap[rhs]!
    }

    // Map from sourcekit name to Acl
    static let sourceKitMap = [String : DefAcl](
        uniqueKeysWithValues: DefAcl.allCases.map { el in ("source.lang.swift.accessibility.\(el.rawValue)", el) }
    )

    /// Initialize from a sourcekit dictionary
    init(name: String, dict: SourceKittenDict) {
        if name == "deinit" && (dict.attributes ?? []).isEmpty {
            // Dumb special case: deinit inherits directly from its nominal.  Pretend it doesn't.
            self = .internal
        } else if let accessibility = dict.accessibility {
            if let acl = Self.sourceKitMap[accessibility] {
                self = acl
            } else {
                logWarning("Unrecognized accessibility '\(accessibility)' for '\(name)', using `internal`.")
                self = .internal
            }
        } else {
            // SourceKit not offering an opinion.  Assume `internal`.
            // This is an extension[ member] without an explicit ACL.
            // We *could* do a bit better here, when we link these exts to a type and
            // discover the type is 'fileprivate' or something, demote the contents to
            // that acl -- but protocols make it tricky, and probably identifying public
            // vs not-public is the 95%+ case.
            Stats.inc(.importGuessedAcl)
            self = .internal
        }
    }

    /// Placeholder acl for obj C decls
    static var forObjC: DefAcl {
        .open
    }

    /// List of ACLs included by one
    static func includedBy(acl: DefAcl) -> [DefAcl] {
        allCases.filter { $0 >= acl }
    }

    /// List of ACLs excluded by one
    static func excludedBy(acl: DefAcl) -> [DefAcl] {
        allCases.filter { $0 < acl }
    }
}
