// swift-tools-version:6.4

import PackageDescription

let package = Package(
  name: "Bebop",
  platforms: [
    .macOS("27.0")
  ],
  products: [
    .executable(name: "bebop", targets: ["BebopCLI"]),
    .library(name: "BebopLib", targets: ["BebopLib"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.0"),
    .package(url: "https://github.com/johnfairh/SourceKitten.git",
             branch: "jf-swift64-msgpack"),
    .package(url: "https://github.com/johnfairh/GRMustache.swift.git",
             from: "14.0.1"),
    // Duplicate SourceKitten's requirement for general sanity
    .package(url: "https://github.com/drmohundro/SWXMLHash.git",
             .upToNextMinor(from: "7.0.2")),
    .package(url: "https://github.com/swiftlang/swift-syntax.git",
             exact: "604.0.0-prerelease-2026-06-05"),
    .package(url: "https://github.com/johnfairh/Maaku.git",
             branch: "master"),
    .package(url: "https://github.com/ole/SortedArray.git",
             from: "0.7.0"),
    .package(url: "https://github.com/stephencelis/SQLite.swift.git",
             .upToNextMinor(from: "0.12.0")),
    .package(url: "https://github.com/swiftlang/swift-format",
             exact: "604.0.0-prerelease-2025-12-17"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git",
             .upToNextMinor(from: "0.5.0"))
  ],
  targets: [
    .target(
      name: "BebopLib",
      dependencies: [
        "Yams",
        .product(name: "SourceKittenFramework", package: "SourceKitten"),
        .product(name: "Mustache", package: "GRMustache.swift"),
        "SWXMLHash",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        "Maaku",
        "SortedArray",
        .product(name: "SQLite", package: "SQLite.swift"),
        "libsass",
        .product(name: "SwiftFormat", package: "swift-format"),
        .product(name: "Subprocess", package: "swift-subprocess")
      ],
      exclude: ["Info.plist"]
      ),
    .executableTarget(
      name: "BebopCLI",
      dependencies: ["BebopLib"]),
    .testTarget(
      name: "BebopTests",
      dependencies: ["BebopLib"],
      exclude: ["Info.plist", "Fixtures"]),
    .systemLibrary(name: "libsass",
        pkgConfig: "libsass",
        providers: [
            .apt(["libsass-dev"]),
            .brew(["libsass"])
    ])
  ]
)
