# Bebop FW2020 theme and related stuff
# Copyright 2019-2020 Bebop Authors
# Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)

all: dist

# Stuff to publish to the theme
THEMEFILES=fw2020.css \
	fw2020.js \
	dependencies.min.js

THEMEPATHS=$(addprefix dist/, ${THEMEFILES})

# Stuff to publish to extensions/katex
KATEX_CSS_FILES=fonts katex.min.css
KATEX_CSS_PATHS=$(addprefix node_modules/katex/dist/, ${KATEX_CSS_FILES})
KATEX_JS_FILES=katex.min.js
KATEX_JS_PATHS=$(addprefix node_modules/katex/dist/, ${KATEX_JS_FILES})

# Stuff to publish to extensions/jazzy_patch
JAZZY_PATCH_CSS_FILES=patch.min.css
JAZZY_PATCH_CSS_PATHS=$(addprefix dist/, ${JAZZY_PATCH_CSS_FILES})
JAZZY_PATCH_JS_FILES=patch.min.js
JAZZY_PATCH_JS_PATHS=$(addprefix dist/, ${JAZZY_PATCH_JS_FILES})
JAZZY_PATCH_FILES=${JAZZY_PATCH_CSS_FILES} ${JAZZY_PATCH_JS_FILES}

# Stuff for testing
DISTFILES= \
	${THEMEFILES} \
	${JAZZY_PATCH_FILES}\
	fw2020.min.css.map \
	guide.html \
	class.html \
	swift-only.html \
	search.json \
	brand.jpg \

DISTPATHS=$(addprefix dist/, ${DISTFILES})

vpath %.scss scss
vpath %.js js
vpath %.html test

# Build css

SCSSFILES=$(addsuffix .scss, main variables fw2020 code-theme-light code-theme-dark colors)
SCSSPATHS=$(addprefix scss/, ${SCSSFILES})

dist/%.css: ${SCSSPATHS}
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
	node_modules/terser/bin/terser $^ -o $@ \
		--comments '/@license|^!/'

dist/patch.min.js: prism/prism.min.js js/prism-extras.js js/jazzy-patch.js
	node_modules/terser/bin/terser $^ -o $@ \
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

jazzy: dist
	mkdir -p dist/jazzy/templates
	mkdir -p dist/jazzy/assets/js
	mkdir -p dist/jazzy/assets/css
	cp -f templates/jazzy/* dist/jazzy/templates/
	cp -f dist/*.js dist/jazzy/assets/js/
	cp -f dist/fw2020.css dist/jazzy/assets/css/
	@echo "Jazzy theme dir: ${PWD}/dist/jazzy"

bebop: dist
	mkdir -p dist/bebop/templates
	mkdir -p dist/bebop/assets/js
	mkdir -p dist/bebop/assets/css
	cp -f templates/bebop/* dist/bebop/templates/
	cp -f dist/dependencies.min.js dist/fw2020.js dist/bebop/assets/js/
	cp -f dist/fw2020.css dist/bebop/assets/css/

publish: bebop
	cp -Rf dist/bebop/* ../Resources/themes/fw2020/

katex:
	cp -Rf ${KATEX_CSS_PATHS} ../Resources/extensions/katex/css/
	cp -Rf ${KATEX_JS_PATHS} ../Resources/extensions/katex/js/

jazzy_patch:
	cp -Rf $ ${JAZZY_PATCH_CSS_PATHS} ../Resources/extensions/jazzy_patch/css/
	cp -Rf $ ${JAZZY_PATCH_JS_PATHS} ../Resources/extensions/jazzy_patch/js/

publish_all: publish katex jazzy_patch
