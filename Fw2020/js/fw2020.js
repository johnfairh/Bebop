// J2 FW2020 theme.
//
// Distributed under the MIT license, https://github.com/johnfairh/J2/blob/master/LICENSE
//
$(function() {
    $("#navToggleButton").click(function() {
        const $nav = $("#navColumn")
        $nav.toggleClass("d-none")
    });
});

Prism.languages.swift['keyword'] = [
    /\b(?:as|Any|assignment|associatedtype|associativity|break|case|catch|class|continue|convenience|default|defer|deinit|didSet|do|dynamic|else|enum|extension|fallthrough|false|fileprivate|final|for|func|get|guard|higherThan|if|import|in|indirect|infix|init|inout|internal|is|lazy|left|let|lowerThan|mutating|nil|none|nonmutating|open|operator|optional|override|postfix|precedencegroup|prefix|private|protocol|public|repeat|required|rethrows|return|right|safe|self|Self|set|some|static|struct|subscript|super|switch|throws?|true|try|Type|typealias|unowned|unsafe|var|weak|where|while|willSet)\b/,
    /#(?:available|colorLiteral|column|fileLiteral|function|imageLiteral|line|selector|sourceLocation)/,
    /@\w+/,
    /\$\d+/
];

Prism.languages.swift['tag'] = /#(?:else|elseif|endif|error|if|warning)/;

Prism.languages.swift['punctuation'] = [ /[{}[\]().,:;=@&?!\\]/, /->/ ];

Prism.languages.swift['class-name'] = {
    pattern: /(\b(?:associatedtype|class|enum|extension|func|let|operator|protocol|precendencegroup|struct|typealias|var)\s+)`?\p{L}[\p{L}_\p{N}]*`?/u,
    lookbehind: true
};

Prism.languages.swift['builtin'] = /\b\p{Lu}[\p{L}_\p{N}]*/u;

delete Prism.languages.swift['boolean'];
delete Prism.languages.swift['constant'];
delete Prism.languages.swift['atrule'];
delete Prism.languages.swift['function'];

Prism.plugins.customClass.map((className, language) => {
    return 'pr-'+className;
});

Prism.plugins.autoloader['languages_path'] = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.17.1/components/";
