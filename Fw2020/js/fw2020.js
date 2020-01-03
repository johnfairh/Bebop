// J2 FW2020 theme.
//
// Distributed under the MIT license, https://github.com/johnfairh/J2/blob/master/LICENSE
//

/* global $ Prism anchors lunr */

'use strict'

const $body = $('body')

//
// Language-switching controls
//
const langControl = {

  // Sync body style from URL for initial layout
  setup () {
    if (window.location.search !== '') {
      $body.removeClass('j2-swift j2-objc')
      $body.addClass('j2-' + window.location.search.substr(1))
    }
  },

  // Initial chrome and event handlers when ready
  ready () {
    this.langMenu = $('#languageMenu')
    this.langSwift = $('#language-swift')
    this.langObjC = $('#language-objc')
    this.actionLang = $('#action-language')

    this.updateChrome()

    this.langSwift.click(() => this.menuItemClicked('j2-swift'))
    this.langObjC.click(() => this.menuItemClicked('j2-objc'))
    this.actionLang.click(() => { this.toggle(); return false })
  },

  // Sync chrome from body
  updateChrome () {
    if ($body.hasClass('j2-swift')) {
      this.langMenu.text('Swift')
      this.langObjC.removeClass('font-weight-bolder')
      this.langSwift.addClass('font-weight-bolder')
      this.actionLang.text('Objective-C (l)')
      return 'swift'
    } else {
      this.langMenu.text('ObjC')
      this.langSwift.removeClass('font-weight-bolder')
      this.langObjC.addClass('font-weight-bolder')
      this.actionLang.text('Swift (l)')
      return 'objc'
    }
  },

  // Update for a menu click
  menuItemClicked (className) {
    this.langMenu.dropdown('toggle')
    if (!$body.hasClass(className)) {
      this.toggle()
    }
    return false
  },

  // Flip current on keypress/click
  toggle () {
    $body.toggleClass('j2-swift j2-objc')
    const lang = this.updateChrome()
    const currentHash = window.location.hash
    window.history.replaceState({}, document.title, '?' + lang + currentHash)
  }
}

//
// Collapse management
//
const collapseControl = {

  // Distinguish user-uncollapse from global
  toggling: false,

  setup () {
    // When we follow a link to the title of a collapsed item,
    // uncollapse it.
    $(window).on('hashchange', () => this.ensureUncollapsed())
  },

  // Helper to uncollapse at the current anchor
  ensureUncollapsed () {
    const $el = $(window.location.hash)
    if ($el.hasClass('j2-item-anchor')) {
      const $collapse = $('#_' + $el.attr('id'))
      $collapse.collapse('show')
    }
  },

  updateChrome () {
    this.actionCollapse.text(this.allCollapsed ? 'Expand (a)' : 'Collapse (a)')
  },

  ready () {
    // Default collapse toggle state
    this.actionCollapse = $('#action-collapse')
    this.allCollapsed = $('.collapse.show').length === 0
    this.updateChrome()

    // If the browser URL has an item's hash, but the user
    // collapses that item and then follows a link to that _same_
    // item, then poke it so we uncollapse it again (there's no
    // `hashchange` event here)
    $("a:not('.j2-item-title')").click((e) => {
      if (window.location.href === e.target.href) {
        this.ensureUncollapsed()
      }
    })

    // When a collapsed item opens, update the browser URL
    // to point at the item's title _without_ creating a
    // new history entry.
    $('.j2-item-popopen-wrapper').on('show.bs.collapse', (e) => {
      if (this.toggling) return
      const title = $(e.target).attr('id')
      window.history.replaceState({}, document.title, '#' + title.substr(1))
    })

    this.actionCollapse.click(() => { this.toggle(); return false })

    // If we loaded the page with a link to a collapse anchor, uncollapse it.
    this.ensureUncollapsed()
  },

  // Collapse/Uncollapse all on keypress/link
  toggle () {
    this.toggling = true
    if (this.allCollapsed) {
      $('.collapse').collapse('show')
    } else {
      $('.collapse').collapse('hide')
    }
    this.toggling = false
    this.allCollapsed = !this.allCollapsed
    this.updateChrome()
  }
}

langControl.setup()
collapseControl.setup()

$(function () {
  // Narrow size nav toggle
  $('#navToggleButton').click(function () {
    const $nav = $('#navColumn')
    $nav.toggleClass('d-none')
  })

  // Auto-add anchors to headings
  anchors.options.visible = 'touch'
  anchors.add('.j2-anchor span')

  // Sync content mode from URL
  langControl.ready()

  // Initialise collapse-anchor link
  collapseControl.ready()

  // Searchbar action
  $('#action-search').click(() => { $('input:visible').focus(); return false })
})

// Keypress handler

$(document).keypress(function (e) {
  const $searchField = $('input:visible')
  if ($searchField.is(':focus')) {
    return
  }

  switch (e.key) {
    case '/': $searchField.focus(); return false
    case 'a': collapseControl.toggle(); break
    case 'l': langControl.toggle(); break
  }
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

/*
 * Lunr/Typeahead/Search
 */
$(function () {
  const $typeahead = $('[data-typeahead]')
  const rootPath = $body.data('root-path')

  function dropdownHtml (suggestion, secondary, el) {
    return `<div class="tt-droprow">\
            <${el} class="tt-sug-name">${suggestion}</${el}>\
            <${el} class="tt-sug-parent-name">${secondary}</${el}>\
            </div>`
  }

  function suggestionHtml (result, el) {
    return dropdownHtml(result.name, result.parent_name || '', el)
  }

  function notFoundTemplate () {
    return dropdownHtml('<i>No matches</i>', '', 'span')
  }

  $typeahead.one('focus', function (e) {
    $.getJSON(rootPath + '/search.json').then(function (searchData) {
      const searchIndex = lunr(function () {
        this.ref('url')
        this.field('name')
        this.field('abstract')
        for (const [url, doc] of Object.entries(searchData)) {
          this.add({ url: url, name: doc.name, abstract: doc.abstract })
        }
      })

      const $searchEntry = $(e.target)
      const searchEntryFormat = $searchEntry.data('search-format')

      $searchEntry.typeahead(
        {
          highlight: true,
          minLength: 3,
          autoselect: true
        },
        {
          limit: 10,
          displayKey: 'name',
          templates: {
            suggestion: (r) => suggestionHtml(r, searchEntryFormat),
            notFound: notFoundTemplate
          },
          source: function (query, sync) {
            const lcSearch = query.toLowerCase()
            const results = searchIndex.query(function (q) {
              q.term(lcSearch, { boost: 100 })
              q.term(lcSearch, {
                boost: 10,
                wildcard: lunr.Query.wildcard.TRAILING
              })
            }).map(function (result) {
              const doc = searchData[result.ref]
              doc.url = result.ref
              return doc
            })
            sync(results)
          }
        }
      )
      $searchEntry.trigger('focus')
    })
  })

  $typeahead.on('typeahead:select', function (e, result) {
    window.location = rootPath + '/' + result.url
  })
})
