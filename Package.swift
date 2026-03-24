// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DaystingIRC",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DaystingIRC", targets: ["DaystingIRC"])
    ],
    targets: [
        .executableTarget(
            name: "DaystingIRC",
            path: "Sources"
        )
    ]
)
