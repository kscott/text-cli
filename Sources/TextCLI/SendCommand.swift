// SendCommand.swift
//
// Handles the `text send` command — resolves recipient and sends via Messages.app.

import Foundation
import TextLib
import GetClearKit

func handleSend(args: [String], contacts: [MessageContact]) throws {
    guard args.count > 2 else { fail("provide a contact and message") }
    let query   = args[1]
    let message = args.dropFirst(2).joined(separator: " ")

    guard let target = resolveSendTarget(query, contacts: contacts) else {
        throw TextError.notFound(query)
    }
    try sendViaMessages(to: target.address, message: message)
    try? ActivityLog.write(tool: "text", cmd: "send", desc: "\(target.name): \(message)", container: nil)
    print("Sent to \(ANSI.bold(target.name)) \(ANSI.dim("(\(target.address))"))")
}
