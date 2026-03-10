// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sms-cli",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic — no framework dependencies, fully testable
        .target(
            name: "MessagesLib",
            path: "Sources/MessagesLib"
        ),
        // Main binary — Contacts for lookup, sqlite3 for reading history,
        // osascript for sending via Messages.app
        .executableTarget(
            name: "sms-bin",
            dependencies: ["MessagesLib"],
            path: "Sources/MessagesCLI",
            linkerSettings: [
                .linkedFramework("Contacts"),
            ]
        ),
        // Test runner — no Xcode required
        .executableTarget(
            name: "sms-tests",
            dependencies: ["MessagesLib"],
            path: "Tests/MessagesLibTests"
        ),
    ]
)
