// main.swift
//
// Entry point for sms-bin executable.
// Contacts access for name/phone resolution, osascript for sending via Messages.app.
// Phone normalization and matching delegated to MessagesLib.

import Foundation
import Contacts
import MessagesLib
import GetClearKit

let version = builtVersion
let args    = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("""
    sms \(version) — Send iMessages and SMS from the terminal

    Usage:
      sms send <contact> <message...>     # Send a message
      sms open [contact]                  # Open Messages.app

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

// MARK: - Error types

enum SMSError: Error, LocalizedError {
    case sendFailed(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .sendFailed(let m): return "Send failed: \(m)"
        case .notFound(let q):   return "Not found: \(q)"
        }
    }
}

// MARK: - Contacts loading

private let keysToFetch: [CNKeyDescriptor] = [
    CNContactGivenNameKey      as CNKeyDescriptor,
    CNContactFamilyNameKey     as CNKeyDescriptor,
    CNContactPhoneNumbersKey   as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
]

func loadMessageContacts(from store: CNContactStore) -> [MessageContact] {
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    var results: [MessageContact] = []
    try? store.enumerateContacts(with: request) { c, _ in
        let name   = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let phones = c.phoneNumbers.map { $0.value.stringValue }
        let emails = c.emailAddresses.map { $0.value as String }
        if !name.isEmpty {
            results.append(MessageContact(name: name, phones: phones, emails: emails))
        }
    }
    return results
}

// MARK: - AppleScript send

func appleScriptLiteral(_ s: String) -> String {
    // AppleScript doesn't support escape sequences in string literals.
    // Split on double quotes and rejoin with the `quote` constant.
    let parts = s.components(separatedBy: "\"")
    if parts.count == 1 { return "\"\(s)\"" }
    return parts.map { "\"\($0)\"" }.joined(separator: " & quote & ")
}

func sendViaMessages(to address: String, message: String) throws {
    let script = """
    tell application "Messages"
        send \(appleScriptLiteral(message)) to buddy \(appleScriptLiteral(address))
    end tell
    """

    // Write to a temp file — avoids shell arg length limits and escaping issues
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("sms-send-\(UUID().uuidString).applescript")
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
        throw SMSError.sendFailed(errMsg)
    }
}

// MARK: - Dispatch

let dispatch = parseArgs(args)
if case .version = dispatch { print(version); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)

store.requestAccess(for: .contacts) { granted, _ in
    let contacts = granted ? loadMessageContacts(from: store) : []

    do {
        switch cmd {

        case "what":
            let rangeStr = args.count > 1 ? Array(args.dropFirst()).joined(separator: " ") : "today"
            guard let range = parseRange(rangeStr) else { fail("Unrecognised range: \(rangeStr)") }
            let isToday = rangeStr == "today"
            let entries: [ActivityLogEntry]
            var dateUsed = Date()
            if isToday {
                let result = ActivityLogReader.entriesForDisplay(in: range.start...range.end)
                entries  = result.entries
                dateUsed = result.dateUsed
            } else {
                entries = ActivityLogReader.entries(in: range.start...range.end, tool: "sms")
            }
            print(ActivityLogFormatter.perToolWhat(entries: entries, range: range, rangeStr: rangeStr,
                                                   tool: "sms", dateUsed: dateUsed))

        case "open":
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            if args.count > 1 {
                let query = args.dropFirst().joined(separator: " ")
                if let target = resolveSendTarget(query, contacts: contacts) {
                    p.arguments = ["sms:\(target.address)"]
                } else {
                    p.arguments = ["-a", "Messages"]
                }
            } else {
                p.arguments = ["-a", "Messages"]
            }
            try p.run()
            p.waitUntilExit()

        case "send":
            guard granted else { fail("Contacts access required") }
            guard args.count > 2 else { fail("provide a contact and message") }
            let query   = args[1]
            let message = args.dropFirst(2).joined(separator: " ")

            guard let target = resolveSendTarget(query, contacts: contacts) else {
                throw SMSError.notFound(query)
            }
            try sendViaMessages(to: target.address, message: message)
            try? ActivityLog.write(tool: "sms", cmd: "send", desc: "\(target.name): \(message)", container: nil)
            print("Sent to \(ANSI.bold(target.name)) \(ANSI.dim("(\(target.address))"))")

        default:
            usage()
        }
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    semaphore.signal()
}

semaphore.wait()


UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
