# Fullwidth 2020
This is a Swift/ObjC docs website theme, designed for J2.  There are static
test pages and a Swift-only [jazzy](https://github.com/realm/jazzy) theme with
cut-down features.

Responsive design, auto dark mode, screen-reader friendly, translation-ready,
Dash mode. Cut-down [demo](https://johnfairh.github.io/RubyGateway/).

## Dependencies
* [Bootstrap](https://getbootstrap.com) for CSS and some JS bits
* [JQuery](https://jquery.com) for stuff
* [AnchorJS](https://www.bryanbraun.com/anchorjs/) for auto heading anchors
* [Typeahead](https://github.com/corejavascript/typeahead.js) for typeahead
* [Lunr](https://lunrjs.com) for search
* [Prism](https://prismjs.com) for syntax highlighting

## Building
Clone the repo, go to this directory, and do `npm install`.

Then `make` will produce some test webpages in `dist`.

And `make jazzy` will produce a jazzy theme in `dist/jazzy`.  It somewhat works
with stock jazzy; use [bebop](https://github.com/johnfairh/jazzy) for best
results.

## Developing
Doing `npm run watch` will auto-rebuild `dist` whenever any of the input scss /
js / html files change.  The jazzy theme doesn't auto-rebuild.
