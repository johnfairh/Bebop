// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "Bebop",
  platforms: [
    .macOS("12.0")
  ],
  products: [
    .executable(name: "bebop", targets: ["BebopCLI"]),
    .library(name: "BebopLib", targets: ["BebopLib"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    .package(url: "https://github.com/jpsim/SourceKitten.git",
             from: "0.33.0"),
    .package(url: "https://github.com/johnfairh/GRMustache.swift.git",
             from: "14.0.1"),
    // Duplicate SourceKitten's requirement for general sanity
    .package(url: "https://github.com/drmohundro/SWXMLHash.git",
             .upToNextMinor(from: "7.0.0")),
    .package(url: "https://github.com/apple/swift-syntax.git",
             exact: "509.0.0"),
    .package(url: "https://github.com/johnfairh/Maaku.git",
             branch: "master"),
    .package(url: "https://github.com/ole/SortedArray.git",
             from: "0.7.0"),
    .package(url: "https://github.com/stephencelis/SQLite.swift.git",
             .upToNextMinor(from: "0.12.0")),
    .package(url: "https://github.com/apple/swift-format",
             exact: "509.0.0")
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
        .product(name: "SwiftFormat", package: "swift-format")
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
