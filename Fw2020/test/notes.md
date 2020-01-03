# Size classes

XL
* Titlebar with coverage/search/lang/icons
* Breadcrumbs
* Nav max 300px
* Article centers, content max 800px at XL then proportionally
* Aux nav on right, topics and actions
* Titlebar, breadcrumbs, nav, aux nav all sticky
* Footer

* LG
* As XL, no aux nav

MD
* As LG, max 250px iwdth

SM, XS
* Titlebar with hamburger, no coverage, lang/icons
* Separate searchbar
* Breadcrumbs, Article, Footer
* Fullwidth Nav when popped up
* Nothing sticky

Tiny (iPhone SE/8)
* As SM, icons gone from header

# Header

* Brand unreactive mouseover unless customized
* Coverage unobtrusive
* Searchbar
  * Low-contrast placeholder text
  * Snaps wide with focus on wide mode
  * See [search](#search)
* Lang
  * React on mouseover
  * Menu opens on top, is sticky when titlebar is (scroll article)
  * No macOS blue border on use
  * Current lang bold, highlight on hover
* Icons
  * React on mouseover

# Breadcrumbs

* Can't select separators
* Links react

# Nav

* Vertical and horizontal scroll when sticky
* Six styles in search of better names:
  * Top-level, top-level active
  * Nested module, nested module active
  * Nested item, nested item active
* Link hitbox extends full column
* Size-class debug

# Article

* Background color all the way to the end
* Links
  * In text, blue and reactive without decoration
  * In inline code, same
  * In pre/code blocks, natural color with reactive
* Four types of callout - no title on the declaration
* Tables
  * Free tables single bordered, stripy rows
  * Param tables same, param name right/top-aligned
* Pre blocks scroll horizontally, no wrap

# Footer

* Small text, bg matches nav and breadcrumbs.

# Syntax highlight

* Swift and ObjC picks out CapitalProbableTypes
* Swift picks out declaration terms -- backticks count
* Missing grammars autoloaded (java)
* Selected text legible

# Dark mode

System settings seems more reliable than Safari tools??

* Text slightly bolder, all readable, check:
  * Searchbar placeholder
  * Dropdown highlighting
  * Syntax highlighting
* Drop shadow on searchbar input focus

# Available

* Main, slightly into declaration callout
* Cleared - if no discussion does not extend into topics
* Item, aligns with discussion.
* Cleared - protrudes a little into declaration

# Collapse

* Click to open updates location hash but not history.
* Link to anchor adjusts for fixed heading
* Link to anchor has zero-adjust if heading not fixed
* Collapse opens on link as part of hash-change -- updates history
* Collapse opens on link if NO hash change
* Page load with location hash scrolls and opens
* Manually opened collapse updates browser hash, preserves language

# Item variations

* Title is just a link
* Title is apple-style mixed-color
* Title is jazzy-style but multi-line
* Title is apple-style and multi-line
* Item is deprecated
* Item has github link
* Item has members link
* Item has note for import/extension method
* Item has default implementation

# Headings

* Link to discussion / topic heading adjust for fixed heading
* Link to discussion / topic heading has zero-adjust if heading not fixed
* On desktop, hover headings outside of items shows link icon
* On mobile, link icon always there, links to pos
* Location hash set to an anchor, no invisible activation area above

# Keys

* '/' focusses searchbar - right searchbar when narrow - without putting
  anything in the searchbar
* '/' while searchbar focus inputs '/'
* 'a' toggles global expand/collapse if searchbar not focus
  * Does not change location hash
* With focus, searchbar works normally
* 'l' toggles Swift/ObjC language: chrome, content, URL; preserves hash
* Escape key in searchbar clears content and focusses body

# Language

* Page-load responds to ?swift or ?objc and updates chrome: titlebar,
  dropdown hilight
* Conditional content updates depending on language
* Rechoosing active language from dropdown has no effect
* Choosing inactive language updates chrome, URL, content

# Search

* Can't load index => error message in dropdown
* As-type search on first char typed, max 10 items
* Wide mode, menu:
  * Item/parent horizontal, no borders
  * Constant width of searchbar
  * Just mashes up if you squeeze a wide one, no wrap
* Narrow mode, menu:
  * Item and parent on separate lines, border between entries
  * Width max searchbar, but sized to widest entry
* Matching prefix highlighted, hint slightly fainter
* Mouseover menu, keys, Enter selects top choice
* 'No matches' feedback when no matches
* 'Loading' feedback while json loads, dunno how to test that
* Not gonna try and specify lunr's algorithm
