// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsageRings",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexUsageRings", targets: ["CodexUsageRings"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "CodexUsageRings", dependencies: [
            "UsageCore", .product(name: "Sparkle", package: "Sparkle")
        ], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageAppTests", dependencies: ["CodexUsageRings", "UsageCore"])
    ],
    swiftLanguageModes: [.v5]
)
