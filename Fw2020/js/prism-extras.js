/*!
 * Bebop FW2020 theme
 * Copyright 2019-2020 Bebop Authors
 * Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
 */

/* global Prism */

'use strict'

/*
 * Prism customization for Swift highlighting.
 * Some of this should go upstream but lots is v. hacky
 * and optimized for declarations >> actual code.
 */
Prism.languages.swift.keyword = [
  {
    // must be first
    pattern: /([^.]|^)\btry[!?]/,
    lookbehind: true
  },
  {
    pattern: /([^.]|^)\b(?:actor|as|Any|assignment|associatedtype|associativity|await|async|break|case|catch|class|continue|convenience|default|defer|deinit|didSet|do|dynamic|else|enum|extension|fallthrough|false|fileprivate|final|for|func|get|guard|higherThan|if|import|in|indirect|infix|init|inout|internal|is|lazy|left|let|lowerThan|mutating|nil|none|nonisolated|nonmutating|open|operator|optional|override|postfix|precedencegroup|prefix|private|protocol|public|repeat|required|rethrows|return|right|safe|self|Self|set|some|static|struct|subscript|super|switch|throws?|true|try|Type|typealias|unowned|unsafe|var|weak|where|while|willSet)(?!`)\b/,
    lookbehind: true
  },
  /#(?:available|colorLiteral|column|fileLiteral|function|imageLiteral|line|selector|sourceLocation)/,
  /@\w+/
]

// Stop $0 etc from being numbers
Prism.languages.insertBefore('swift', 'number', {
  workaround: {
    pattern: /\$\w+/,
    alias: 'punctuation'
  }
})

// _ is not a number; exp valid without decimal point
Prism.languages.swift.number = [
  /-?\b\d[\d_]*(?:\.?[\de_]+)?\b/i,
  /-?\b0x[a-f0-9_]+(?:\.?[a-f0-9p_]+)?\b/i,
  /-?\b0b[01_]+|0o[0-7_]+\b/i
]

Prism.languages.insertBefore('swift', 'function', {
  tag: /#(?:else|elseif|endif|error|if|warning)/
})

{
  // Barely approximate...
  const id = '`?[\\p{L}_][\\p{L}_\\p{N}]*`?'
  const idl = '`?[\\p{Ll}_][\\p{L}_\\p{N}]*`?'
  const idu = '`?[\\p{Lu}][\\p{L}_\\p{N}]*`?'

  Prism.languages.swift.function = [
    {
      // param labels
      pattern: new RegExp(`([,(]\\s*)${idl}(?=\\s+${idl})`, 'u'),
      lookbehind: true
    },
    // params and calls
    new RegExp(`\\b${idl}(?=[(:])`, 'u')
  ]

  // Declarations.
  Prism.languages.swift['class-name'] = {
    pattern: new RegExp(`(\\b(?:associatedtype|case|class|enum|extension|func|let|operator|protocol|precedencegroup|struct|typealias|var)\\s+)${id}`, 'u'),
    lookbehind: true
  }

  // Color (probable) type refs
  Prism.languages.swift.builtin = new RegExp(`\\b${idu}`, 'u')
}

delete Prism.languages.swift.boolean
delete Prism.languages.swift.constant
delete Prism.languages.swift.atrule

/*
 * Prism customization for Objective-C highlighting.
 * Add property attributes and nullability to keywords.
 * Add a load of tenuous regexps to prettify declarations.
 */
Prism.languages.objectivec.keyword = [
  /\b(?:asm|typeof|inline|auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|id|in|instancetype|self|super)\b|(?:@interface|@end|@implementation|@protocol|@class|@public|@protected|@private|@property|@try|@catch|@finally|@throw|@synthesize|@dynamic|@selector)\b/,
  /\b(?:(non)?atomic|class|readonly|readwrite|strong|weak|assign|copy)\b/,
  /\b(?:nonnull|nullable|_Nullable|_Nonnull)\b/,
  /\b(?:getter=|setter=)/
]

delete Prism.languages.objectivec.function

{
  const id = '[A-Za-z]\\w*'

  Prism.languages.insertBefore('objectivec', 'keyword', {
    // Declarations of things
    'class-name': [
      {
        // First part of message name
        pattern: new RegExp(`([+-]\\s*[(].*?[)]\\s*)${id}`),
        lookbehind: true
      },
      // Later parts of message name
      new RegExp(`\\b${id}(?=:\\s*[(])`),
      {
        // Property declarations
        pattern: new RegExp(`(@property.*?)\\b${id}(?=(?:;|$))`),
        lookbehind: true
      },
      {
        // Simple declarations
        pattern: new RegExp(`((?:struct|typedef|enum|union|@interface|@protocol|@implementation|@class)\\s+)${id}`),
        lookbehind: true
      }
    ],
    // Function args in declaration & name-parts in usage
    function: [
      // In message-send, sending arg
      new RegExp(`\\b${id}(?=\\s*:)`),
      {
        // 0-args message send
        pattern: new RegExp(`([^:])\\b${id}(?=\\s*])`),
        lookbehind: true
      },
      {
        // In message declaration
        pattern: new RegExp(`(:\\s*[(].*?[)]\\s*)${id}`),
        lookbehind: true
      },
      {
        // In property decls
        pattern: new RegExp(`([sg]etter=\\s*)${id}`),
        lookbehind: true
      }
    ],
    // Things that are probably types
    builtin: /\b[A-Z]\w*/
  })

  Prism.languages.insertBefore('objectivec', 'punctuation', {
    c_function: {
      pattern: new RegExp(`\\b${id}(?=\\s*\\()`),
      alias: 'function'
    }
  })
}
