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
    let autolink: FormatAutolink

    init(autolink: FormatAutolink) {
        self.autolink = autolink
    }

    func visit(defItem: DefItem, parents: [Item]) {
        defItem.formatDeclarations { text in
            // Must escape _first_ because autolink introduces actual HTML that
            // does not want to be escaped.
            // Means if we decide to handle generic expressions Foo<Bar>.Baz then
            // will need to expect for "&lt;"...
            let escaped = text.htmlEscaped

            // veery approximate...
            let linked = escaped.re_sub(#"\b\p{Lu}[\w.]*"#) { name in
                guard let link = autolink.link(for: name, context: defItem) else {
                    return name
                }
                return #"<a href="\#(link.primaryURL)">\#(name)</a>"#
            }
            return Html(linked)
        }
    }
}
