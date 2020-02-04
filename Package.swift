// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "J2",
  platforms: [
    .macOS("10.13")
  ],
  products: [
    .executable(name: "j2", targets: ["J2Lib", "J2CLI"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "2.0.0"),
    .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.29.0"),
    .package(url: "https://github.com/johnfairh/GRMustache.swift.git",
             from: "14.0.1"),
    // Duplicate SourceKitten's requirement for general sanity
    .package(url: "https://github.com/drmohundro/SWXMLHash.git",
             .upToNextMinor(from: "5.0.1")),
    .package(url: "https://github.com/apple/swift-syntax.git",
             .exact("0.50100.0")),
    .package(url: "https://github.com/johnfairh/Maaku.git",
             from: "10.9.3")
  ],
  targets: [
    .target(
      name: "J2Lib",
      dependencies: [
        "Yams",
        "SourceKittenFramework",
        "Mustache",
        "SWXMLHash",
        "SwiftSyntax",
        "Maaku"
      ]),
    .target(
      name: "J2CLI",
      dependencies: ["J2Lib"]),
    .testTarget(
      name: "J2Tests",
      dependencies: ["J2Lib"],
      exclude: ["Fixtures"]),
  ]
)
