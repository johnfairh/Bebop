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
	docker run -v `pwd`:`pwd` -w `pwd` --name bebop --rm swift:5.6 /bin/bash -c "apt-get update; apt-get install libsqlite3-dev libsass0 libsass-dev; make test"

shell_linux:
	docker run -it -v `pwd`:`pwd` -w `pwd` --name bebop --rm swift:5.6 /bin/bash

install: build
	-mkdir -p ${PREFIX}/share ${PREFIX}/bin
	install ${BIN_PATH}/bebop ${PREFIX}/bin
	cp -r Resources/ ${PREFIX}/share/bebop.resources

uninstall:
	rm -f ${PREFIX}/bin/bebop
	rm -rf ${PREFIX}/share/bebop.resources

# magic symlinks to workaround weird Xcode bugs
#
# Under /Users/johnf/Library/Developer/Xcode/DerivedData/Bebop-aejdbemlzzwgclhebgtaksojykdu/Build/Products/Debug
# 1. lib_InternalSwiftSyntaxParser.dylib
# 2. BebopCLI.app/Contents/Frameworks/lib_InternalSwiftSyntaxParser.dylib
#
# Both point to /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/lib_InternalSwiftSyntaxParser.dylib

DERIVED_DATA := $(shell xcodebuild -showBuildSettings|grep ' BUILD_DIR = ' | awk '{print $$3}')
DD_DEBUG := ${DERIVED_DATA}/Debug

SS_DYLIB := lib_InternalSwiftSyntaxParser.dylib

XCODE_DYLIB := /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/${SS_DYLIB}

xcode_symlinks:
	ln -sf ${XCODE_DYLIB} ${DD_DEBUG}/${SS_DYLIB}
	ln -sf ${XCODE_DYLIB} ${DD_DEBUG}/BebopCLI.app/Contents/Frameworks/${SS_DYLIB}
