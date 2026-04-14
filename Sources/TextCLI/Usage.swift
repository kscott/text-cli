// Usage.swift
//
// Usage string and exit for text-cli.

import Foundation

func usage() -> Never {
    print("""
    text \(versionString) — Send iMessages and SMS from the terminal

    Usage:
      text send <contact> <message...>     # Send a message
      text open [contact]                  # Open Messages.app

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}
