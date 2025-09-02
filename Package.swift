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
            url: "https://prelude-public.s3.amazonaws.com/sdk/releases/apple/core/0.1.2/PreludeCore-0.1.2.xcframework.zip",
            checksum: "12e109eb82ec0ccb7807fc7e20815df0df8dd1061322a6b3f9269034fc439d3a"
        ),
    ]
)
