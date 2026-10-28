// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToDo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ToDo",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
