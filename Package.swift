// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HomeControl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HomeControl", targets: ["HomeControl"]),
        .executable(name: "HomeControlCLI", targets: ["HomeControlCLI"])
    ],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "HomeCore"),
        .executableTarget(name: "HomeControl", dependencies: ["HomeCore", .product(name: "Sparkle", package: "Sparkle")], resources: [.copy("Resources")],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "HomeControlCLI", dependencies: ["HomeCore"]),
        .testTarget(name: "HomeCoreTests", dependencies: ["HomeCore"])
    ],
    swiftLanguageModes: [.v5]
)
