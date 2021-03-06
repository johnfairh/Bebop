// swift-tools-version:5.4

import PackageDescription

let package = Package(
  name: "Bebop",
  platforms: [
    .macOS("10.15")
  ],
  products: [
    .executable(name: "bebop", targets: ["BebopCLI"]),
    .library(name: "BebopLib", targets: ["BebopLib"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.0"),
    .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.30.0"),
    .package(name: "Mustache",
             url: "https://github.com/johnfairh/GRMustache.swift.git",
             from: "14.0.1"),
    // Duplicate SourceKitten's requirement for general sanity
    .package(url: "https://github.com/drmohundro/SWXMLHash.git",
             .upToNextMinor(from: "5.0.1")),
    .package(name: "SwiftSyntax",
             url: "https://github.com/apple/swift-syntax.git",
             .exact("0.50400.0")),
    .package(url: "https://github.com/johnfairh/Maaku.git",
             from: "10.9.5"),
    .package(url: "https://github.com/ole/SortedArray.git",
             from: "0.7.0"),
    .package(url: "https://github.com/stephencelis/SQLite.swift.git",
             from: "0.12.0"),
    .package(url: "https://github.com/apple/swift-format",
             .exact("0.50400.0"))
  ],
  targets: [
    .target(
      name: "BebopLib",
      dependencies: [
        "Yams",
        .product(name: "SourceKittenFramework", package: "SourceKitten"),
        "Mustache",
        "SWXMLHash",
        "SwiftSyntax",
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
