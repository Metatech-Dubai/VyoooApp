// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_callkit_incoming",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-callkit-incoming", targets: ["flutter_callkit_incoming"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "flutter_callkit_incoming",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ]
        )
    ]
)
