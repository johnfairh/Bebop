sdk=`xcrun --show-sdk-path --sdk macosx`
all:
	TOOLCHAINS=swift-dev swiftc -emit-module Extensions.swift Protocols.swift SpmSwiftModule.swift -module-name SpmSwiftModule -sdk $(sdk)
