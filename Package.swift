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
            url: "https://prelude-public.s3.amazonaws.com/sdk/releases/apple/core/0.3.1/PreludeCore-0.3.1.xcframework.zip",
            checksum: "23fc8ffb25fbed3307eebb0fb59848d530712dc8b91690133bf7c591f465ce5a"
        ),
    ]
)
