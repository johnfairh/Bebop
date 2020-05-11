//
//  FormatDeclaration.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

/// Create declaration HTMLs
///
/// The declaration HTML will be wrapped in <pre><code> tags.  We need to:
/// 1) Do a painful line-wrapping thing
///     (Not implemented so far - maybe Nathan's work will let SourceKit do it?)
/// 2) Do autolinking, wrapping typerefs in <a href=> links
/// 3) Do HTML escaping (most obviously <> from generics)
struct DeclarationFormatter: ItemVisitorProtocol {
    let autolink: FormatAutolink

    init(autolink: FormatAutolink) {
        self.autolink = autolink
    }

    func visit(defItem: DefItem, parents: [Item]) {
        defItem.formatDeclarations { text, language in
            // Must escape _first_ because autolink introduces actual HTML that
            // does not want to be escaped.
            // Means if we decide to handle generic expressions Foo<Bar>.Baz then
            // will need to expect "&lt;"...
            let escaped = text.htmlEscaped

            // veery approximate...
            let linked = escaped.re_sub(#"(?:\b|@)\p{Lu}[\w.]*"#) { name in
                guard let link = autolink.link(for: defItem.linkName(for: name),
                                               context: defItem,
                                               contextLanguage: language) else {
                    return name
                }
                return #"<a href="\#(link.primaryURL)">\#(name)</a>"#
            }
            return Html(linked)
        }
    }
}

private extension DefItem {
    /// 'Extensions make everything more complicated' part 92.
    ///
    /// When autolinking the declaration of an extension of a type from another
    /// module, we want to link over to *that* module rather than to ourselves
    /// which is the naive result of evaluating the name in the current scope.
    func linkName(for shortName: String) -> String {
        guard defKind.isSwiftExtension &&
            shortName == name &&
            typeModuleName != location.moduleName else {
            return shortName
        }

        return "\(typeModuleName).\(shortName)"
    }
}
