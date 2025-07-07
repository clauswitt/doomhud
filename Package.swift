// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DoomHUD",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DoomHUD",
            targets: ["DoomHUD"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .executableTarget(
            name: "DoomHUD",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ]
        )
    ]
)