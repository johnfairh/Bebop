In this branch....

Solution for the 'my docs have loads of long-named classes': allow
user to drag the splitbar.

Lots of js splitter plugins out there, some even current (jcubic).

All though want to insert their own div and have lots of flexibility.

This is bad for us wanting to split two bootstrap columns -- adding
a splitter div between them breaks the first rule of bootstrap.

So, easiest way is to roll our own.

template.html updates to relayout the left nav to include a vertical
flush-right div to be a split-bar.  Basic flexbox learning!

JS would be simple enough: capture mousedown and track move/up.
Set min-width & max-width (for consistency with responsive css) on the
column; job done.

Quirk: have to constrain max to avoid bootstrap putting the article on
a new row.  And deal with close-to-zero-width.

Accessibility is a thing, requires tabindex etc. and key handlers (easier
than mouse move...) and aria attribute sprinkling.

Shelved because doesn't seem good solution really, just polish.

Either the docs need a wider nav or they don't.  If they do we should let
the doc author control that.  So will provide a theme override to control
the max-width behaviour instead.
