# `make` to build & install to /usr/local
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
	swift build -c ${RELEASE}

test:
	swift test --parallel

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name bebop --rm swift:5.3 /bin/bash -c "apt-get update; apt-get install libsqlite3-dev libsass0 libsass-dev; swift test --parallel --enable-test-discovery"

install: build
	install ${BIN_PATH}/bebop ${PREFIX}/bin
	cp -r Resources/ ${PREFIX}/share/bebop.resources

uninstall:
	rm -f ${PREFIX}/bin/bebop
	rm -rf ${PREFIX}/share/bebop.resources
