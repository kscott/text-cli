// main.swift
//
// Entry point for sms-bin executable.
// Contacts access for name resolution, SQLite for reading history,
// osascript for sending via Messages.app.
// Matching and phone normalization delegated to MessagesLib.

import Foundation
import Contacts
import SQLite3
import MessagesLib

let version = "1.0.0"
let args    = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    fputs("Error: \(msg)\n", stderr)
    exit(1)
}

func usage() -> Never {
    print("""
    sms \(version) — CLI for Messages via iMessage/SMS

    Usage:
      sms send <contact> <message...>     # Send a message
      sms list [n]                        # Recent conversations (default 10)
      sms show <contact>                  # Message history with a contact
      sms open [contact]                  # Open Messages.app
    """)
    exit(0)
}

// MARK: - Error types

enum SMSError: Error, LocalizedError {
    case sendFailed(String)
    case notFound(String)
    case dbUnavailable(String)
    case dbError(String)

    var errorDescription: String? {
        switch self {
        case .sendFailed(let m):    return "Send failed: \(m)"
        case .notFound(let q):      return "Not found: \(q)"
        case .dbUnavailable(let m): return m
        case .dbError(let m):       return "Database error: \(m)"
        }
    }
}

// MARK: - SQLite helpers

typealias SQLiteDB = OpaquePointer

func openChatDB() throws -> SQLiteDB {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Messages/chat.db").path
    guard FileManager.default.fileExists(atPath: path) else {
        throw SMSError.dbUnavailable("chat.db not found at \(path)")
    }
    guard FileManager.default.isReadableFile(atPath: path) else {
        throw SMSError.dbUnavailable(
            "Cannot read chat.db — grant Full Disk Access to Terminal in System Settings → Privacy & Security")
    }
    var db: SQLiteDB?
    let result = sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil)
    guard result == SQLITE_OK, let db else {
        throw SMSError.dbError("Cannot open chat.db (SQLite error \(result))")
    }
    return db
}

func queryDB(_ db: SQLiteDB, sql: String, params: [String] = []) throws -> [[String: Any]] {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        let msg = String(cString: sqlite3_errmsg(db))
        throw SMSError.dbError("Prepare failed: \(msg)")
    }
    defer { sqlite3_finalize(stmt) }

    for (i, param) in params.enumerated() {
        sqlite3_bind_text(stmt, Int32(i + 1), (param as NSString).utf8String, -1, nil)
    }

    var rows: [[String: Any]] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        var row: [String: Any] = [:]
        for col in 0..<sqlite3_column_count(stmt) {
            let name = String(cString: sqlite3_column_name(stmt, col))
            switch sqlite3_column_type(stmt, col) {
            case SQLITE_INTEGER: row[name] = Int64(sqlite3_column_int64(stmt, col))
            case SQLITE_FLOAT:   row[name] = Double(sqlite3_column_double(stmt, col))
            case SQLITE_TEXT:    row[name] = String(cString: sqlite3_column_text(stmt, col)!)
            default:             break
            }
        }
        rows.append(row)
    }
    return rows
}

// MARK: - Date helpers

/// Convert an Apple-epoch timestamp (seconds or nanoseconds) to a Date.
/// chat.db stores nanoseconds since 2001-01-01 on macOS 10.15+.
func appleDate(_ raw: Int64) -> Date {
    let appleEpoch: TimeInterval = 978307200  // seconds between Unix and Apple epoch
    let seconds: TimeInterval = raw > 1_000_000_000_000
        ? Double(raw) / 1_000_000_000.0
        : Double(raw)
    return Date(timeIntervalSince1970: seconds + appleEpoch)
}

func formatMsgDate(_ date: Date) -> String {
    let cal = Calendar.current
    let now = Date()
    let df  = DateFormatter()
    if cal.isDateInToday(date) {
        df.dateFormat = "h:mma"
        return df.string(from: date).lowercased()
    } else if cal.isDateInYesterday(date) {
        df.dateFormat = "h:mma"
        return "yesterday \(df.string(from: date).lowercased())"
    } else if cal.component(.year, from: date) == cal.component(.year, from: now) {
        df.dateFormat = "MMM dd h:mma"
        return df.string(from: date).lowercased()
    } else {
        df.dateFormat = "yyyy MMM dd"
        return df.string(from: date)
    }
}

func formatListDate(_ date: Date) -> String {
    let cal = Calendar.current
    let now = Date()
    let df  = DateFormatter()
    if cal.isDateInToday(date) {
        df.dateFormat = "h:mma"
        return df.string(from: date).lowercased()
    } else if cal.component(.year, from: date) == cal.component(.year, from: now) {
        df.dateFormat = "MMM dd"
        return df.string(from: date)
    } else {
        df.dateFormat = "yyyy"
        return df.string(from: date)
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
    let addrLiteral = appleScriptLiteral(address)
    let msgLiteral  = appleScriptLiteral(message)

    let script = """
    tell application "Messages"
        send \(msgLiteral) to buddy \(addrLiteral)
    end tell
    """

    // Write to temp file to avoid argument-length limits and shell escaping issues
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

// MARK: - Commands

func runSend(contactQuery: String, message: String, contacts: [MessageContact]) throws {
    guard !message.isEmpty else { fail("provide a message") }

    guard let target = resolveSendTarget(contactQuery, contacts: contacts) else {
        throw SMSError.notFound(contactQuery)
    }

    try sendViaMessages(to: target.address, message: message)
    print("Sent to \(target.name) (\(target.address))")
}

func runList(n: Int, contacts: [MessageContact]) throws {
    let db = try openChatDB()
    defer { sqlite3_close(db) }

    // Fetch the most recent N conversations with their last message
    let sql = """
        SELECT
            c.chat_identifier,
            c.display_name,
            m.text,
            m.date,
            m.is_from_me
        FROM chat c
        JOIN chat_message_join cmj ON c.ROWID = cmj.chat_id
        JOIN message m ON cmj.message_id = m.ROWID
        WHERE m.ROWID IN (
            SELECT MAX(m2.ROWID)
            FROM message m2
            JOIN chat_message_join cmj2 ON m2.ROWID = cmj2.message_id
            WHERE cmj2.chat_id = c.ROWID
              AND m2.text IS NOT NULL
              AND m2.text != ''
        )
        ORDER BY m.date DESC
        LIMIT ?
        """
    let rows = try queryDB(db, sql: sql, params: [String(n)])

    if rows.isEmpty { print("No messages found."); return }

    for (i, row) in rows.enumerated() {
        let identifier = row["chat_identifier"] as? String ?? ""
        let displayName = row["display_name"] as? String ?? ""
        let text     = row["text"]   as? String ?? ""
        let rawDate  = row["date"]   as? Int64  ?? 0
        let fromMe   = (row["is_from_me"] as? Int64 ?? 0) != 0

        // Resolve display name: contact lookup > chat display_name > formatted identifier
        let name = resolveIdentifier(identifier, contacts: contacts)
            ?? (displayName.isEmpty ? nil : displayName)
            ?? (identifier.contains("@") ? identifier : formatPhone(identifier))

        let date    = appleDate(rawDate)
        let dateStr = formatListDate(date).leftPad(8)
        let nameStr = String(name.prefix(22)).padding(toLength: 22, withPad: " ", startingAt: 0)
        let preview = String((fromMe ? "You: " : "") + text).prefix(50)
        let idx     = String(i + 1).leftPad(3)

        print("  \(idx)  \(dateStr)  \(nameStr)  \(preview)")
    }
}

func runShow(contactQuery: String, contacts: [MessageContact]) throws {
    let db = try openChatDB()
    defer { sqlite3_close(db) }

    // Find matching chat identifier
    // First try to resolve via contacts to get their phone/email
    let target = resolveSendTarget(contactQuery, contacts: contacts)
    let searchTerm = target?.address ?? contactQuery

    // Find matching chats
    let chatSQL = """
        SELECT ROWID, chat_identifier, display_name
        FROM chat
        WHERE chat_identifier LIKE '%' || ? || '%'
           OR display_name LIKE '%' || ? || '%'
        LIMIT 5
        """
    let chatRows = try queryDB(db, sql: chatSQL, params: [searchTerm, contactQuery])

    guard let chat = chatRows.first else {
        throw SMSError.notFound(contactQuery)
    }

    if chatRows.count > 1 {
        print("(\(chatRows.count) conversations found — showing first match)\n")
    }

    let chatId     = chat["ROWID"] as? Int64 ?? 0
    let identifier = chat["chat_identifier"] as? String ?? ""
    let chatName   = resolveIdentifier(identifier, contacts: contacts)
        ?? (chat["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        ?? (identifier.contains("@") ? identifier : formatPhone(identifier))

    print("--- \(chatName) ---")

    // Fetch messages
    let msgSQL = """
        SELECT m.text, m.date, m.is_from_me
        FROM message m
        JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
        WHERE cmj.chat_id = ?
          AND m.text IS NOT NULL
          AND m.text != ''
        ORDER BY m.date DESC
        LIMIT 50
        """
    var messages = try queryDB(db, sql: msgSQL, params: [String(chatId)])
    messages.reverse()  // show oldest first

    for msg in messages {
        let text    = msg["text"]       as? String ?? ""
        let rawDate = msg["date"]       as? Int64  ?? 0
        let fromMe  = (msg["is_from_me"] as? Int64 ?? 0) != 0

        let date    = appleDate(rawDate)
        let dateStr = formatMsgDate(date)
        let who     = fromMe ? "You" : chatName
        let padding = fromMe ? "  " : ""

        print("  \(padding)\(dateStr.leftPad(16))  \(who): \(text)")
    }
}

// MARK: - String padding helper

extension String {
    func leftPad(_ length: Int) -> String {
        if count >= length { return self }
        return String(repeating: " ", count: length - count) + self
    }
}

// MARK: - Dispatch

guard let cmd = args.first else { usage() }
if cmd == "--version" || cmd == "-v" { print(version); exit(0) }
if cmd == "--help"    || cmd == "-h" { usage() }

// `open` and `list`/`show` without send don't strictly need contacts,
// but contacts access makes list/show much more useful. Request it for all commands.

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)

store.requestAccess(for: .contacts) { granted, _ in
    let contacts = granted ? loadMessageContacts(from: store) : []

    do {
        switch cmd {

        case "open":
            let contactArg = args.count > 1 ? args.dropFirst().joined(separator: " ") : nil
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            if let contactArg {
                // Try to resolve to a phone/email and open a specific conversation
                if let target = resolveSendTarget(contactArg, contacts: contacts) {
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
            guard granted else { fail("Contacts access required to resolve recipient") }
            guard args.count > 2 else { fail("provide a contact and message") }
            let contactQuery = args[1]
            let message      = args.dropFirst(2).joined(separator: " ")
            try runSend(contactQuery: contactQuery, message: message, contacts: contacts)

        case "list":
            let n = args.count > 1 ? (Int(args[1]) ?? 10) : 10
            try runList(n: n, contacts: contacts)

        case "show":
            guard args.count > 1 else { fail("provide a contact name") }
            let query = args.dropFirst().joined(separator: " ")
            try runShow(contactQuery: query, contacts: contacts)

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
