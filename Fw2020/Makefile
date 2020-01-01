# Copyright
#

all: dist

# Stuff to publish to the theme
THEMEFILES=fw2020.min.css \
	fw2020.js \
	jquery.slim.min.js \
	bs-util.js \
	bs-dropdown.js \
	bs-collapse.js \
	prism.min.js \
	prism.css \
	anchor.js

THEMEPATHS=$(addprefix dist/, ${THEMEFILES})

# Stuff for testing
DISTFILES=${THEMEFILES} \
	fw2020.min.css.map \
	jquery.slim.min.map \
	util.js.map \
	dropdown.js.map \
	collapse.js.map \
	guide.html \
	class.html \
	gh.png \
	dash.png \

DISTPATHS=$(addprefix dist/, ${DISTFILES})

vpath %.scss scss
vpath %.js js
vpath %.js prism
vpath %.js node_modules/anchor-js
vpath %.html test

# Build css

SCSSFILES=$(addsuffix .scss, main variables fw2020)

dist/%.css: ${SCSSFILES}
	npm run css

dist/prism.css: prism/prism.css
	cp -f $^ $@

# Assemble js

dist/%.js: %.js
	cp -f $^ $@

JQUERY_DIST=node_modules/jquery/dist

dist/%: ${JQUERY_DIST}/%
	cp -f $^ $@

BOOTSTRAP_JS_DIST=node_modules/bootstrap/js/dist

dist/bs-%: ${BOOTSTRAP_JS_DIST}/%
	cp -f $^ $@

dist/%: ${BOOTSTRAP_JS_DIST}/%
	cp -f $^ $@

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
