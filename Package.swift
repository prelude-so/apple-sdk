// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prelude",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "Prelude",
            targets: ["Prelude", "PreludeCore"]
        ),
    ],
    targets: [
        .target(
            name: "Prelude",
            dependencies: ["PreludeCore"]
        ),
        .binaryTarget(
            name: "PreludeCore",
            url: "https://prelude-public.s3.amazonaws.com/sdk/releases/apple/core/0.3.0/PreludeCore-0.3.0.xcframework.zip",
            checksum: "dd8aecb2881c5289b5a4322c02b3c93439fe84cf49ab4af249649aad60988553"
        ),
    ]
)
