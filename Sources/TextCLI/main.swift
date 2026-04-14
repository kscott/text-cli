// main.swift
//
// Entry point for text-bin executable. Argument parsing and dispatch only.

import Foundation
import Contacts
import TextLib
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)

store.requestAccess(for: .contacts) { granted, _ in
    let contacts = granted ? loadMessageContacts(from: store) : []

    do {
        switch cmd {
        case "what": handleWhat(args: args)
        case "open": try handleOpen(args: args, contacts: contacts)
        case "send":
            guard granted else { fail("Contacts access required") }
            try handleSend(args: args, contacts: contacts)
        default: usage()
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
