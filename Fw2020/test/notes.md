# Size classes

XL,LG
* Titlebar with coverage/search/lang/icons
* Breadcrumbs
* Nav max 300px
* Article sticks left, content max 800px
* Titlebar, breadcrumbs, nav all sticky
* Footer

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
  * Light placeholder text
  * Snaps wide with focus
  * (XXX function, hotkey)
* Lang
  * React on mouseover
  * Menu opens on top, is sticky when titlebar is (scroll article)
  * No macOS blue border on use
  * Current lang bold, highlight on hover
  * (XXX function)
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
  * Free tables single bordered, stripey rows
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

# Misc

* Link to discussion / topic heading adjust for fixed heading
* Link to discussion / topic heading has zero-adjust if heading not fixed

