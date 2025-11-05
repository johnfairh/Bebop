# `make install` to build & install to /usr/local
# `make uninstall` to uninstall from /usr/local
#
# `RELEASE=debug make install` to build & install debug to /usr/local
# `PREFIX=/opt make install` to build & install release to /opt

PREFIX ?= /usr/local
RELEASE ?= release
BIN_PATH := $(shell swift build --show-bin-path -c ${RELEASE})

.PHONY: build test test_linux install uninstall

all: build 

build:
	swift build -c ${RELEASE} --disable-sandbox

test:
	swift test --enable-code-coverage

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name bebop --rm swift:6.2 /bin/bash -c "apt-get update; apt-get install make libsqlite3-dev libsass1 libsass-dev; make test"

shell_linux:
	docker run -it -v `pwd`:`pwd` -w `pwd` --name bebop --rm swift:6.2 /bin/bash

install: build
	-mkdir -p ${PREFIX}/share ${PREFIX}/bin ${PREFIX}/lib
	install ${BIN_PATH}/bebop ${PREFIX}/bin
	cp -r Resources/ ${PREFIX}/share/bebop.resources

uninstall:
	rm -f ${PREFIX}/bin/bebop
	rm -f ${PREFIX}/lib/lib_InternalSwiftSyntaxParser.dylib
	rm -rf ${PREFIX}/share/bebop.resources
