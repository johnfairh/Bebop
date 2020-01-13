# J2 FW2020 theme
# Copyright 2019-2020 J2 Authors
# Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)

all: dist

# Stuff to publish to the theme
THEMEFILES=fw2020.min.css \
	fw2020.js \
	dependencies.min.js

THEMEPATHS=$(addprefix dist/, ${THEMEFILES})

# Stuff for testing
DISTFILES=${THEMEFILES} \
	fw2020.min.css.map \
	guide.html \
	class.html \
	search.json \
	brand.jpg \

DISTPATHS=$(addprefix dist/, ${DISTFILES})

vpath %.scss scss
vpath %.js js
vpath %.html test

# Build css

SCSSFILES=$(addsuffix .scss, main variables fw2020 code-themes colors)

dist/%.css: ${SCSSFILES}
	npm run css

# Assemble js

dist/%.js: %.js
	cp -f $^ $@

JS_DEPENDENCIES= \
	node_modules/jquery/dist/jquery.min.js \
	node_modules/bootstrap/js/dist/util.js \
	node_modules/bootstrap/js/dist/dropdown.js \
	node_modules/bootstrap/js/dist/collapse.js \
	prism/prism.min.js \
	js/prism-extras.js \
	node_modules/anchor-js/anchor.min.js \
	node_modules/lunr/lunr.min.js \
	node_modules/corejs-typeahead/dist/typeahead.jquery.min.js

dist/dependencies.min.js: ${JS_DEPENDENCIES}
	node_modules/uglify-js/bin/uglifyjs $^ -o $@ \
		--comments '/@license|^!/'

# Build htmls
dist/%.html: %-article-frag.html template.html
	sed -e '/<!-- ARTICLE -->/r $<' test/template.html > $@

# misc test files
dist/%: test/%
	cp -f $^ $@

# Targets
#

dist: ${DISTPATHS}

publish: ${THEMEPATHS}
	@echo cp -f $^ Somewhere....
	@echo need to figure out where these go
