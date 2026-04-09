// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "text-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear.git", branch: "main"),
    ],
    targets: [
        // Pure logic — no framework dependencies, fully testable
        .target(
            name: "TextLib",
            path: "Sources/TextLib"
        ),
        // Main binary — Contacts for lookup, sqlite3 for reading history,
        // osascript for sending via Messages.app
        .executableTarget(
            name: "text-bin",
            dependencies: [
                "TextLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Sources/TextCLI",
            linkerSettings: [
                .linkedFramework("Contacts"),
            ]
        ),
        // Test runner — no Xcode required
        .executableTarget(
            name: "text-tests",
            dependencies: ["TextLib"],
            path: "Tests/TextLibTests"
        ),
    ]
)
