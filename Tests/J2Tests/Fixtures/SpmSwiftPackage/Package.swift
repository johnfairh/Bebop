// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "SpmSwiftModule",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SpmSwiftModule",
            targets: ["SpmSwiftModule", "SpmSwiftModule2"]),
    ],
    targets: [
        .target(
            name: "SpmSwiftModule",
            dependencies: []),
        .target(
            name: "SpmSwiftModule2",
            dependencies: [])
    ]
)
