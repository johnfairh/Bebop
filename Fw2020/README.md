# Fullwidth 2020
This is a Swift/ObjC docs website theme, designed for Bebop.

Responsive design, auto dark mode, screen-reader friendly, translation-ready,
Dash mode. Cut-down [demo](https://johnfairh.github.io/RubyGateway/).

## Dependencies
* [Bootstrap](https://getbootstrap.com) for CSS and some JS bits
* [JQuery](https://jquery.com) for stuff
* [AnchorJS](https://www.bryanbraun.com/anchorjs/) for auto heading anchors
* [Typeahead](https://github.com/corejavascript/typeahead.js) for typeahead
* [Lunr](https://lunrjs.com) for search
* [Prism](https://prismjs.com) for syntax highlighting
* [KaTeX](https://katex.org) for TeX rendering

## Building
Clone the repo, go to this directory, and do `npm install`.

Then `make` will produce some test webpages in `dist`, for css/js.

And `make publish` will push everything and templates over to
the Resources part of Bebop.

## Developing
Doing `npm run watch` will auto-rebuild `dist` whenever any of the input scss /
js / html files change.
