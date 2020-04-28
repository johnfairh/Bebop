PREFIX ?= /usr/local
BIN_PATH := $(shell swift build --show-bin-path)

TEST_COMMAND=swift test --parallel

.PHONY: build all

all: build install

build:
	swift build -c release

test:
	${TEST_COMMAND}

test_linux:
	docker run -v `pwd`:`pwd` -w `pwd` --name j2 --rm swift:5.2 /bin/bash -c "apt-get update; apt-get install libsqlite3-dev libsass0 libsass-dev; swift test --parallel --enable-test-discovery"

install:
	install ${BIN_PATH}/j2 ${PREFIX}/bin
	cp -r Resources/ ${PREFIX}/share/j2.resources

uninstall:
	rm ${PREFIX}/bin/j2
	rm -r ${PREFIX}/share/j2.resources
