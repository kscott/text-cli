// MessagesClient.swift
//
// Build and send messages via Messages.app using AppleScript.

import Foundation

/// Escape a string for safe embedding in an AppleScript string literal.
///
/// AppleScript does not support escape sequences inside quoted strings.
/// Double quotes are handled by splitting on `"` and rejoining with the
/// built-in `quote` constant, which evaluates to a literal double-quote character.
///
/// Example: `say "hi"` → `"say " & quote & "hi" & quote & ""`
public func appleScriptLiteral(_ s: String) -> String {
    let parts = s.components(separatedBy: "\"")
    if parts.count == 1 { return "\"\(s)\"" }
    return parts.map { "\"\($0)\"" }.joined(separator: " & quote & ")
}

/// Build the AppleScript string that sends a message to a recipient.
///
/// Both arguments are escaped via `appleScriptLiteral` before embedding.
/// This is a pure function — separately testable from the Process execution in `sendViaMessages`.
public func buildScript(recipient: String, message: String) -> String {
    """
    tell application "Messages"
        send \(appleScriptLiteral(message)) to buddy \(appleScriptLiteral(recipient))
    end tell
    """
}

/// Send a message via Messages.app using osascript.
///
/// Writes the script to a temp file to avoid shell argument length limits and
/// escaping issues, then runs osascript and cleans up.
public func sendViaMessages(to address: String, message: String) throws {
    let script = buildScript(recipient: address, message: message)

    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("text-send-\(UUID().uuidString).applescript")
    try script.write(to: tmpURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = [tmpURL.path]
    let errPipe = Pipe()
    p.standardError = errPipe

    try p.run()
    p.waitUntilExit()

    guard p.terminationStatus == 0 else {
        let data   = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errMsg = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "AppleScript error"
        throw TextError.sendFailed(errMsg)
    }
}
