// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_network_watcher",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "flutter-network-watcher", targets: ["flutter_network_watcher"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_network_watcher",
            dependencies: [],
            resources: []
        )
    ]
)
