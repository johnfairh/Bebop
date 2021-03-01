## Inherited Docs

The default behaviour is to inherit docs.  If you don't write docs for a method
(etc.) that overrides something, and that something has Swift docs available,
then the docs from the superclass/protocol are copied in.

The `--inherited-docs-style` option can be used to disable this or change the
default of 'full' inheritance to 'brief' -- sometimes useful with the Swift
Stdlib to avoid pulling in exhaustive documentation comments.

The inherited docs style is set separately for extensions of types from
external modules using `--inherited-docs-extension-style` -- the default here is
to inherit just brief documentation.

Another tool here is `:nodoc:` which is a more selective way of omitting decls
from documentation.  This makes it clear in the source code that it's
intentionally omitted.

## Syntax Highlighting

Syntax highlighting is done by Javascript in the browser using
[Prism](https://prismjs.com).  The Prism build provided with the Bebop theme has
built-in support for some languages and attempts to fetch syntax definition
files for others on demand from [cdnjs](https://cdnjs.com).

The built-in languages are: Bash, C, C++, CMake, CSS, Diff, Javascript, Json,
Make, Markup / HTML / XML / SVG, Objective-C, Protobuf, Python, Ruby, and Swift.

### Changing the CDN

To change the CDN used for fetching missing Prism languages, make a custom
copy of the theme with `--products theme` and change the
`Prism.plugins.autoloader.languages_path` line in `fw2020.js`.

### Avoiding the CDN

To avoid accessing the CDN you'll need to cook up a custom version of Prism.
You'll need various build tools including `npm` to rebuild the theme dependencies.

1. Go to the [Prism download page](https://prismjs.com/download.html).
2. Choose `Minified version` and the `Default` theme.
3. Choose the languages you want.  Don't deselect Swift or Objective-C.
4. Choose two plugins:
    * Custom Class; and
    * Keep Markup.
   The theme will not work properly without these.  I haven't tested what
   happens if you include any others.
5. Download the JS.  Ignore the theme button.
6. Clone the Bebop project, go into the `Fw2020` directory and do `npm install`.
7. Replace `Fw2020/prism/prism.min.js` with your custom version
8. Do `make` - you should get a new version of `Fw2020/dist/bebop/dependencies.min.js`.
9. Make a private copy of the Bebop theme `bebop --products theme --output my-theme`.
10. Replace the `dependencies.min.js` 
11. Build your docs using your new theme `bebop --theme my-theme`.

## Theme structure

`theme.yaml` is optional -- if missing though Bebop runs in Jazzy-compatible mode:
* Individually run each `assets/css/*.css.scss` file through sass
* Generate Jazzy-style mustache template data
* Inject Prism Javascript and CSS files for syntax highlighting via `{{{custom_head}}}`

So normally there should be a `theme.yaml` to produce Bebop-style output.  Keys:
* `mustache_root` name of the root template file in `templates/`.
* `file_extension` of the generated files: `.html` or `.md`.
* `scss_filenames` list of root sass files in `assets/css`, compiled such that
  they can `@import` from that directory.
* `localized_strings` name of a yaml file in `templates/` with strings to merge
  into the mustache build -- localized via language-tag subdirectories.
* `default_language_tag` language tag of the default `localized_strings` file.

Clone a built-in theme using `bebop --products=theme --output=mytheme`, edit, then
run against it using `bebop --theme=mytheme`.
