// J2 FW2020 theme.
//
// Distributed under the MIT license, https://github.com/johnfairh/J2/blob/master/LICENSE
//

/* global $ Prism anchors */

'use strict'

let allCollapsed = false

const $body = $('body')

// Language-switching stuff
const langControl = {

  // Sync body style from URL for initial layout
  setup () {
    if (window.location.search !== '') {
      $body.removeClass('j2-swift j2-objc')
      $body.addClass('j2-' + window.location.search.substr(1))
    }
  },

  // Initial chrome and event handlers when ready
  documentLoaded () {
    this.langMenu = $('#languageMenu')
    this.langSwift = $('#language-swift')
    this.langObjC = $('#language-objc')

    this.updateChrome()

    this.langSwift.click(function () {
      langControl.set('j2-swift')
    })
    this.langObjC.click(function () {
      langControl.set('j2-objc')
    })
  },

  // Sync chrome from body
  updateChrome () {
    if ($body.hasClass('j2-swift')) {
      this.langMenu.text('Swift')
      this.langSwift.addClass('font-weight-bolder')
      this.langObjC.removeClass('font-weight-bolder')
      return 'swift'
    } else {
      this.langMenu.text('ObjC')
      this.langSwift.removeClass('font-weight-bolder')
      this.langObjC.addClass('font-weight-bolder')
      return 'objc'
    }
  },

  // Update for a menu click
  set (className) {
    if (!$body.hasClass(className)) {
      this.toggle()
    }
  },

  // Flip current on keypress/click
  toggle () {
    $body.toggleClass('j2-swift j2-objc')
    const lang = this.updateChrome()
    window.history.replaceState({}, document.title, '?' + lang)
  }
}

langControl.setup()

$(function () {
  // Narrow size nav toggle
  $('#navToggleButton').click(function () {
    const $nav = $('#navColumn')
    $nav.toggleClass('d-none')
  })

  // Auto-add anchors to headings
  anchors.options.visible = 'touch'
  anchors.add('.j2-anchor span')

  // Default collapse toggle state
  allCollapsed = $('.collapse.show').length === 0

  langControl.documentLoaded()

  // Page load to an item title that need to trigger uncollapse
  $(window).trigger('hashchange')
})

// Keypress handler

$(function () {
  $(document).keypress(function (e) {
    const $searchField = $('input:visible')
    if ($searchField.is(':focus')) {
      return
    }

    switch (e.key) {
      case '/': {
        e.preventDefault()
        $searchField.focus()
        break
      }

      case 'a':
        if (allCollapsed) {
          $('.collapse').collapse('show')
        } else {
          $('.collapse').collapse('hide')
        }
        allCollapsed = !allCollapsed
        break

      case 'l':
        langControl.toggle()
        break
    }
  })
})

// When we follow a link to the title of a collapsed item,
// uncollapse it.
$(window).on('hashchange', function (e) {
  const $el = $(window.location.hash)
  if ($el.hasClass('j2-item-anchor')) {
    const $collapse = $('#_' + $el.attr('id'))
    $collapse.collapse('show')
  }
})

// If the browser URL has an item's hash, but the user
// collapses that item and then follows a link to that _same_
// item, then poke it so we uncollapse it again.
$("a:not('.j2-item-title')").on('click', function () {
  if (window.location.href === this.href) {
    $(window).trigger('hashchange')
  }
})

// When a collapsed item opens, update the browser URL
// to point at the item's title _without_ creating a
// new history entry.
$('.j2-item-popopen-wrapper').on('show.bs.collapse', function () {
  const title = $(this).attr('id')
  window.history.replaceState({}, document.title, '#' + title.substr(1))
})

/*
 * Prism customization for Swift highlighting.
 * Some of this should go upstream.
 */
Prism.languages.swift.keyword = [
  /\b(?:as|Any|assignment|associatedtype|associativity|break|case|catch|class|continue|convenience|default|defer|deinit|didSet|do|dynamic|else|enum|extension|fallthrough|false|fileprivate|final|for|func|get|guard|higherThan|if|import|in|indirect|infix|init|inout|internal|is|lazy|left|let|lowerThan|mutating|nil|none|nonmutating|open|operator|optional|override|postfix|precedencegroup|prefix|private|protocol|public|repeat|required|rethrows|return|right|safe|self|Self|set|some|static|struct|subscript|super|switch|throws?|true|try|Type|typealias|unowned|unsafe|var|weak|where|while|willSet)\b/,
  /#(?:available|colorLiteral|column|fileLiteral|function|imageLiteral|line|selector|sourceLocation)/,
  /@\w+/,
  /\$\d+/
]

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
 * This is only to add property attributes.
 */
Prism.languages.objectivec.keyword = [
  /\b(?:asm|typeof|inline|auto|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|int|long|register|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|in|self|super)\b|(?:@interface|@end|@implementation|@protocol|@class|@public|@protected|@private|@property|@try|@catch|@finally|@throw|@synthesize|@dynamic|@selector)\b/,
  /\b(?:(non)?atomic|readonly|readwrite|strong|weak|assign|copy)\b/,
  /\b(?:getter=|setter=)/
]

// Add a bit more color
Prism.languages.objectivec.builtin = /\b[A-Z][\w0-9_]*/

/*
 * Prism customization for CSS tag names.
 */
Prism.plugins.customClass.map((className, language) => {
  return 'pr-' + className
})

/*
 * Prism customization for autoloading missing languages.
 */
Prism.plugins.autoloader.languages_path = 'https://cdnjs.cloudflare.com/ajax/libs/prism/1.17.1/components/'
