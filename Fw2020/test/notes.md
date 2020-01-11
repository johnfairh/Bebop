# Size classes

XL
* Titlebar with coverage/search/lang/icons/locale
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

SM
* Titlebar with hamburger, no coverage, lang/icons/locale
* Separate searchbar
* Breadcrumbs, Article, Footer
* Fullwidth Nav when popped up
* Nothing sticky

XS,
* As SM, icons gone from header

XXS (iPhone SE/8)
* As XS, locale gone from header

# Header

* Screenreader skip link far NW
* Brand unreactive mouseover unless customized
* Coverage unobtrusive
* Searchbar
  * Low-contrast placeholder text
  * Snaps wide with focus on wide mode
  * See [search](#search)
* Lang
  * React on mouseover
  * Menu opens on top, is sticky when titlebar is (scroll article)
  * Menu aligns left from XL down to MD, then right
  * Current lang has tickmark; all highlight on hover
  * Tab navigation
* Icons
  * React on mouseover
  * Alt text
* Locale
  * React on mouseover
  * Menu opens on top, mouseover
  * Current locale has tickmark; all highlight on hover
  * Menu aligns right, expands left into page

# Breadcrumbs

* Can't select separators
* Links react

# Nav

* Vertical and horizontal scroll when sticky
* Top level darker, larger
* Second level no indent, lighter, smaller
* Nth level as second but with an indent
* Active item has pretty background
* Hover inactive shows pretty background
* Link hitbox extends full column
* Size-class debug

# Article

* Background color all the way to the bottom
* Links
  * In text, blue and underlined on hover
  * In inline code, same
  * In pre/code blocks, natural color with underline on hover
* Four types of callout - no title on the declaration (except dash mode)
* Tables
  * Free tables double-bordered outside and around headings, otherwise
    single bordered, striped rows
  * Param tables same, param name right/top-aligned
* Pre blocks scroll horizontally, no wrap

# Aux nav

* Vertical subordinate to article title
* Topics links are blue, underline on hover,
  word-wrap with indent
* Actions links are body and glow on hover.
* 'expand' and 'swift' buttons switch to their
  inverse on use.

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

# Availability

* Main, slightly into declaration callout
* Cleared - if no discussion does not extend into topics
* Item, aligns with discussion
* Cleared - no overlap below

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

# Accessibility

_subject to more screenreader testing_
* header -> main -> article -> section/overview[header] -> section/topics[header] -> section/item[header]s -> footer
* Screenreader-only headings for 'tasks' and item-sections
* Screenreader-only first-prio link
* Nav toggler marked up as button
* Search fields all controlled by the plugin - keystroke marked
* Dropdown menu works as a menu, 'collapsed' live
* XSite links marked up
* Breadcrumbs as a nav, current marked
* Swift and ObjC left-navs marked as such, current marked
* Aux nav nav-part marked as such, actions marked as buttons with keystrokes
* Availability as aside/note
* Section per topic, section per non-'just link' item
* Collapse things marked up, 'collapsed' live
  * _check - can we put the keyshortcut here_
* Strikethrough decls have screenreader-only explanations
* Line art div 'presentation' and ignored
* Callouts as straight divs with role=heading titles
* Heading hierarchy in SR is sensible, everything covered - page 1, topic 2, item 4, callouts 5, mini-menu 6
* Links list in SR is sensible (the 'Anchor' is from anchor.js and seems legit)
