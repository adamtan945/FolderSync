// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "FolderSync",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FolderSync",
            path: "FolderSync"
        )
    ]
)
