//
//  MergeFilter.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// MergeFilter removes defs from the forest that shouldn't be there.
///
/// Filepath include/excludes
///
/// ACL filtering and consequences thereof
///
/// :nodoc:
///
/// skip-undocumented

public struct MergeFilter: Configurable {
    init(config: Config) {
        config.register(self)
    }

    func filter(items: DefItemList) -> DefItemList {
        return items
    }
}
