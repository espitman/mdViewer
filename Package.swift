// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "mdViewer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "mdViewer", targets: ["mdViewer"])
    ],
    targets: [
        .executableTarget(
            name: "mdViewer",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
