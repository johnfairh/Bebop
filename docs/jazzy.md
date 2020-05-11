# Jazzy Incompatibilities and Changes

### Swift

@available attributes processed into sidebar and deprecation notices.

Module name guessed if you leave it out.

Various prettifications.

### CocoaPods

Jazzy picks up a podspec even if you don't ask it to.  That doesn't happen
any more.  Less metadata is picked up from the podspec.

### Markdown

GitHub-flavo[u]red CommonMark instead of Redcarpet.  Mostly more compatible
with what you expect; no more LaTeX-style quote marks though.  All extensions
enabled including task lists.

### Localization

Docs can be in multiple languages; doc comments can be translated.
See [localization](localization.md).

### Web pages

URLs have all changed:
* Layout on disk has changed.
* Naming of things has changed most obviously to stop using USRs in links,
  instead favoring strings formed from the name of the thing.

More customization of bits of text on the page, check the help.

### Themes

Bebop has one HTML theme 'fw2020' with all kinds of features.  The program
can also use custom or stock Jazzy themes which are automatically detected.
This is mostly a migration aide to a fw2020-based theme:
* Default categories (left nav) are different;
* Declaration 'names' are different (improved?);
* Deep links (with #) don't work;
* Syntax highlighting is done by injecting Prism CSS and JS into the Jazzy
  theme which may go wrong.

Bebop has one markdown theme 'md' which is mostly a proof of concept intended
for deployment to github rather than anything more sophisticated.

### Custom Categories

Renamed to 'custom groups', more flexibility with abstracts and topics.
'custom_defs' to control how type members are arranged.

Default prefix for leftovers after custom groups have been applied is
the empty string instead of 'Other'.  Put it back using
'custom_groups_unlisted_prefix' if you want.

### Deleted Options

* `--swift-version`.  Omit: set `DEVELOPER_DIR` manually.
* `--use-safe-filenames`.  Omit: filenames are no longer dangerous.
* `--template-directory`.  Use `--theme`.
* `--assets-directory`.  Use `--theme`.
* `--skip-documentation`.  Use `--products`.
* `--keep-property-attributes`.  Omit.
* `--author_url`.  Use `--author-url`.

### Renamed Options

These options have been renamed but the old versions preserved as
aliases:
* --abstract -> --custom-abstracts
* --author -> --author-name
* --copyright -> --custom-copyright
* --custom-categories -> custom_groups
* --custom-categories-unlisted-prefix -> custom_groups_unlisted_prefix
* --dash_url -> --docset-feed-url
* --disable-search -> --[no-]hide-search
* --documentation -> --guides
* --exclude -> --exclude-source-files
* --framework-root -> --objc-include-paths
* --github-file-prefix -> --code-host-file-url
* --github_url -> --code-host-url
* --head -> --custom-head
* --hide-declarations -> --hide-language
* --hide-documentation-coverage -> --[no-]hide-coverage
* --hide-unlisted-documentation -> --[no-]exclude-unlisted-guides
* --include -> --include-source-files
* --module -> --modules|-m
* --objc -> --[no-]objc-direct
* --root-url -> --deployment-url
* --sourcekitten-sourcefile -> --sourcekitten-json-files|-s
* --swift-build-tool -> --build-tool
* --umbrella-header -> --objc-header-file
* -x, --xcodebuild-arguments -> --build-tool-arguments|-b

See [Options](options.md) for all the options.

### Objective-C
* A working Jazzy config should still work, though there are better names for
  the flags and more rigorous policing of meaningless option combinations.
* `--objc-include-paths` is the renamed `--framework-root`, it is less
  aggressive but should be better targetted.
* New Objective-C build modes available through `--build-tool` that are
  probably slower but may actually work on modern/complicated projects.
    * Not implemented yet!

<!--
See [Objective C notes](???) for more.
-->
