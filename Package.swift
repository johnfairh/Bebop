// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "J2",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .executable(name: "j2", targets: ["J2Lib", "J2CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/johnfairh/RubyGateway", from: "3.2.0")
    ],
    targets: [
        .target(
            name: "J2Lib",
            dependencies: ["RubyGateway"]),
        .target(
            name: "J2CLI",
            dependencies: ["J2Lib"]),
        .testTarget(
            name: "J2Tests",
            dependencies: ["J2Lib"]),
    ]
)
