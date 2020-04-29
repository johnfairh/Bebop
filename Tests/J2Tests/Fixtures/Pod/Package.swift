// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Pod",
    products: [.library( name: "Pod", targets: ["Pod"])],
    dependencies: [],
    targets: [.target(name: "Pod", dependencies: [])]
)
