// swift-tools-version:5.1

import PackageDescription

let baseTargetNames = ["SpmSwiftModule", "SpmSwiftModule2", "SpmSwiftModule3"]

#if os(macOS)
let osTargetNames = ["SpmSwiftModule4", "SpmObjCModule"]
let osTargets: [Target] = [
  /// ObjC->Swift interop
  .target(
    name: "SpmSwiftModule4",
    dependencies: ["SpmObjCModule"]),
  /// ObjC->Swift interop
  .target(
    name: "SpmObjCModule",
    dependencies: [])
]
#else
let osTargetNames = [String]()
let osTargets = [Target]()
#endif

let package = Package(
    name: "SpmSwiftModule",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SpmSwiftModule",
            targets: baseTargetNames + osTargetNames
        ),
    ],
    targets: [
        /// Main module for throwing in features
        .target(
            name: "SpmSwiftModule",
            dependencies: []),
        /// Localizable doc comments testbed
        .target(
            name: "SpmSwiftModule2",
            dependencies: []),
        /// Cross-module extensions with SpmSwiftModule1
        .target(
            name: "SpmSwiftModule3",
            dependencies: ["SpmSwiftModule"])
    ] +
    osTargets
)
