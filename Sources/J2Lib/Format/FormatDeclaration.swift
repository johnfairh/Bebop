//
//  FormatDeclaration.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// Create declaration HTMLs
///
/// The declaration HTML will be wrapped in <pre><code> tags.  We need to:
/// 1) Do a painful line-wrapping thing.
/// 2) Do autolinking, wrapping typerefs in <a href=> links
/// 3) Do HTML escaping (most obviously <> from generics)
struct DeclarationFormatter: ItemVisitorProtocol {
    func visit(defItem: DefItem, parents: [Item]) {
        defItem.formatDeclarations { text in
            Html(text.htmlEscaped)
        }
    }
}
