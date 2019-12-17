# Copyright
#

# Stuff to publish to the theme
THEMEFILES=fw2020.min.css \
		   fw2020.js \
		   jquery.slim.min.js \
		   bs-util.js \
		   bs-dropdown.js

THEMEPATHS=$(addprefix dist/, ${THEMEFILES})

# Stuff for testing
DISTFILES=${THEMEFILES} \
		  fw2020.min.css.map \
		  jquery.slim.min.map \
		  bs-util.js.map \
		  bs-dropdown.js.map

DISTPATHS=$(addprefix dist/, ${DISTFILES})

vpath %.scss scss
vpath %.js js

# Build css

SCSSFILES=$(addsuffix .scss, main variables fw2020)

dist/%.css: ${SCSSFILES}
	npm run css

# Assemble js

dist/%.js: %.js
	cp -f $^ $@

JQUERY_DIST=node_modules/jquery/dist

dist/%: ${JQUERY_DIST}/%
	cp -f $^ $@

BOOTSTRAP_JS_DIST=node_modules/bootstrap/js/dist

dist/bs-%: ${BOOTSTRAP_JS_DIST}/%
	cp -f $^ $@

# Targets

dist: ${DISTPATHS}

all: dist

.PHONY: update_bootstrap
update_bootstrap:
	cp -f bootstrap/.browserslistrc .
	cp -f bootstrap/build/.stylelintrc build/
	cp -f bootstrap/build/postcss.config.js build/

publish: ${THEMEPATHS}
	@echo cp -f $^ Somewhere....
	@echo need to figure out where these go
