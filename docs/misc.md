## Syntax Highlighting

Syntax highlighting is done by Javascript in the browser using
[Prism](https://prismjs.com).  The Prism build provided with the J2 theme has
built-in support for some languages and attempts to fetch syntax definition
files for others on demand from [cdnjs](https://cdnjs.com).

The built-in languages are: Bash, C, C++, CMake, CSS, Diff, Javascript, Json,
Make, Markup / HTML / XML / SVG, Objective-C, Protobuf, Python, Ruby, and Swift.

** Recipes below need validating **

### Changing the CDN

To change the CDN used for fetching missing Prism languages,
[edit the J2 theme](???) and change the
`Prism.plugins.autoloader.languages_path` line in `fw2020.js`.

### Avoiding the CDN

To avoid accessing the CDN you'll need to cook up a custom version of Prism.
This is easy:
1. Go to the [Prism download page](https://prismjs.com/download.html).
2. Choose `Minified version` and the `Default` theme.
3. Choose the languages you want.  Don't deselect Swift or Objective-C.
4. Choose two plugins:
    * Custom Class; and
    * Keep Markup.
    * _What happens if we don't equip the autoloader plugin?_

   The theme will not work properly without these.  I haven't tested what
   happens if you include any others.
5. Download the JS.  Ignore the theme button (see [Theme Customization](???)
    for that).
6. [Edit the J2 theme](???) and replace `prism.min.js` with the file you
   downloaded.
