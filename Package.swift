// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsageRings",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexUsageRings", targets: ["CodexUsageRings"])],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "CodexUsageRings", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageAppTests", dependencies: ["CodexUsageRings", "UsageCore"])
    ],
    swiftLanguageModes: [.v5]
)
