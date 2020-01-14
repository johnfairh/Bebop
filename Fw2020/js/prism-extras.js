/*!
 * J2 FW2020 theme
 * Copyright 2019-2020 J2 Authors
 * Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
 */

/* global Prism */

'use strict'

/*
 * Prism customization for Swift highlighting.
 * Some of this should go upstream.
 */
Prism.languages.swift.keyword = [
  {
    pattern: /([^.]|^)\b(?:as|Any|assignment|associatedtype|associativity|break|case|catch|class|continue|convenience|default|defer|deinit|didSet|do|dynamic|else|enum|extension|fallthrough|false|fileprivate|final|for|func|get|guard|higherThan|if|import|in|indirect|infix|init|inout|internal|is|lazy|left|let|lowerThan|mutating|nil|none|nonmutating|open|operator|optional|override|postfix|precedencegroup|prefix|private|protocol|public|repeat|required|rethrows|return|right|safe|self|Self|set|some|static|struct|subscript|super|switch|throws?|true|try|Type|typealias|unowned|unsafe|var|weak|where|while|willSet)(?!`)\b/,
    lookbehind: true
  },
  /#(?:available|colorLiteral|column|fileLiteral|function|imageLiteral|line|selector|sourceLocation)/,
  /@\w+/,
  /\$\d+/
]

// Use initial case to filter out type initializers from function calls....
// And guess horribly at param lables too
Prism.languages.swift.function = /`?\b\p{Ll}[\p{L}_\p{N}]*`?(?=[(:])/u

// _ is not a number ... this isn't perfect but a slight improvement
Prism.languages.swift.number = /\b(?:\d[\d_]*(?:\.[\de_]+)?|0x[a-f0-9_]+(?:\.[a-f0-9p_]+)?|0b[01_]+|0o[0-7_]+)\b/i

Prism.languages.insertBefore('swift', 'function', {
  tag: /#(?:else|elseif|endif|error|if|warning)/
})

// Color type declarations.  The id regexps are barely approximate.
Prism.languages.swift['class-name'] = {
  pattern: /(\b(?:associatedtype|class|enum|extension|func|let|operator|protocol|precedencegroup|struct|typealias|var)\s+)`?[_\p{L}][\p{L}_\p{N}.]*`?/u,
  lookbehind: true
}

// Color (probable) type refs
Prism.languages.swift.builtin = /\b\p{Lu}[\p{L}_\p{N}]*/u

delete Prism.languages.swift.boolean
delete Prism.languages.swift.constant
delete Prism.languages.swift.atrule

/*
 * Prism customization for Objective-C highlighting.
 * This adds property attributes and nullability
 */
Prism.languages.objectivec.keyword = [
  /\b(?:asm|typeof|inline|auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|in|self|super)\b|(?:@interface|@end|@implementation|@protocol|@class|@public|@protected|@private|@property|@try|@catch|@finally|@throw|@synthesize|@dynamic|@selector)\b/,
  /\b(?:(non)?atomic|readonly|readwrite|strong|weak|assign|copy)\b/,
  /\b(?:nonnull|nullable)\b/,
  /\b(?:getter=|setter=)/
]

delete Prism.languages.objectivec.function

// const id = '\\w[\\w\\d_]*'

Prism.languages.insertBefore('objectivec', 'keyword', {
  // Declarations of things
  'class-name': [
    {
      pattern: /([+-]\s*[(].*?[)]\s*)\w+/,
      lookbehind: true
    },
    /\b\w+(?=:)/,
    {
      pattern: /(@property.*?)\b\w+(?=;)/,
      lookbehind: true
    },
    {
      pattern: /((?:@interface|@protocol|@implementation|@class)\s+)\w+/,
      lookbehind: true
    }
  ],
  // Things that are probably types
  builtin: /\b[A-Z]\S*/,
  // Function arguments
  function: [
    // new RegExp(`\\b${id}(?=;)`),
    /\b\w+(?=;)/,
    {
      pattern: /(:\s*[(].*?[)]\s*)\w+/,
      lookbehind: true
    }
  ]
})
