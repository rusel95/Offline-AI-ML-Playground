// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0"),
    ],
    targets: [
        .target(
            name: "BuildTools",
            path: ""
        )
    ]
)