// OpenCommand.swift
//
// Handles the `text open` command — opens Messages.app, optionally to a contact.

import Foundation
import TextLib

func handleOpen(args: [String], contacts: [MessageContact]) throws {
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
}
