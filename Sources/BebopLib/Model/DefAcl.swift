//
//  DefAcl.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// Swift definition access control level
public enum DefAcl: String, Comparable, CaseIterable, Encodable {
    case `private`
    case `fileprivate`
    case `internal`
    case `public`
    case `open`

    // Map from Acl to number, higher number = more open
    private static let indexMap = [DefAcl : Int](
        uniqueKeysWithValues: DefAcl.allCases.enumerated().map { offs, el in (el, offs) }
    )

    public static func < (lhs: DefAcl, rhs: DefAcl) -> Bool {
        indexMap[lhs]! < indexMap[rhs]!
    }

    // Map from sourcekit name to Acl
    private static let sourceKitMap = [String : DefAcl](
        uniqueKeysWithValues: DefAcl.allCases.map { ($0.sourceKitName, $0) }
    )

    var sourceKitName: String {
        "source.lang.swift.accessibility.\(rawValue)"
    }

    /// Initialize from a sourcekit dictionary
    init(name: String, dict: SourceKittenDict) {
        if name == "deinit" && (dict.attributes ?? []).isEmpty {
            // Dumb special case: deinit inherits directly from its nominal.  Pretend it doesn't.
            self = .internal
        } else if let accessibility = dict.accessibility {
            if let acl = Self.sourceKitMap[accessibility] {
                self = acl
            } else {
                logWarning(.wrnUnknownAcl, accessibility, name)
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
    public static func includedBy(acl: DefAcl) -> [DefAcl] {
        allCases.filter { $0 >= acl }
    }

    /// List of ACLs excluded by one
    public static func excludedBy(acl: DefAcl) -> [DefAcl] {
        allCases.filter { $0 < acl }
    }
}
