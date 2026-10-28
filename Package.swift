// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChainedMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ChainedMac", targets: ["ChainedMac"])
    ],
    targets: [
        .executableTarget(
            name: "ChainedMac",
            path: "Sources/ChainedMac",
            exclude: ["Resources"]
        )
    ]
)
