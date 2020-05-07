# `make` to build & install to /usr/local
# `make uninstall` to uninstall from /usr/local
#
# `RELEASE=DEBUG make` to build & install debug to /usr/local
# `PREFIX=/opt make` to build & install release to /opt

PREFIX ?= /usr/local
RELEASE ?= release
BIN_PATH := $(shell swift build --show-bin-path -c ${RELEASE})

.PHONY: build all

all: build install

build:
	swift build -c ${RELEASE}

test:
	swift test --parallel

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name j2 --rm swift:5.2 /bin/bash -c "apt-get update; apt-get install libsqlite3-dev libsass0 libsass-dev; swift test --parallel --enable-test-discovery"

install:
	install ${BIN_PATH}/j2 ${PREFIX}/bin
	cp -r Resources/ ${PREFIX}/share/j2.resources

uninstall:
	rm -f ${PREFIX}/bin/j2
	rm -rf ${PREFIX}/share/j2.resources
