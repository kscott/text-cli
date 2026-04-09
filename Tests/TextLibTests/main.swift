// main.swift — test runner for TextLib
//
// Does not require Xcode or XCTest — runs with just the Swift CLI toolchain.
// Run via:  text test

import Foundation
import TextLib

// MARK: - Minimal test harness

final class TestRunner: @unchecked Sendable {
    private var passed = 0
    private var failed = 0

    func expect(_ description: String, _ condition: Bool, file: String = #file, line: Int = #line) {
        if condition {
            print("  ✓ \(description)")
            passed += 1
        } else {
            print("  ✗ \(description)  [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
            failed += 1
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    func summary() {
        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

let t = TestRunner()

// MARK: - normalizePhone

t.suite("normalizePhone — 10-digit US numbers") {
    t.expect("bare 10 digits → +1",           normalizePhone("5551234567") == "+15551234567")
    t.expect("formatted (555) 123-4567",      normalizePhone("(555) 123-4567") == "+15551234567")
    t.expect("formatted 555-123-4567",        normalizePhone("555-123-4567") == "+15551234567")
    t.expect("formatted 555.123.4567",        normalizePhone("555.123.4567") == "+15551234567")
}

t.suite("normalizePhone — 11-digit with country code") {
    t.expect("11 digits starting with 1",     normalizePhone("15551234567") == "+15551234567")
    t.expect("1-555-123-4567",                normalizePhone("1-555-123-4567") == "+15551234567")
}

t.suite("normalizePhone — already E.164") {
    t.expect("+15551234567 unchanged",        normalizePhone("+15551234567") == "+15551234567")
    t.expect("international +44 preserved",   normalizePhone("+44 20 7946 0958") == "+442079460958")
}

t.suite("normalizePhone — email pass-through") {
    t.expect("email not modified",            normalizePhone("user@example.com") == "user@example.com")
    t.expect("email with + in local part",    normalizePhone("user+tag@example.com") == "user+tag@example.com")
}

t.suite("normalizePhone — unrecognised input") {
    t.expect("short number returned as-is",   normalizePhone("555") == "555")
    t.expect("empty string returned as-is",   normalizePhone("") == "")
}

// MARK: - phoneMatches

t.suite("phoneMatches — same US number, different formats") {
    t.expect("+15551234567 vs +15551234567",  phoneMatches("+15551234567", "+15551234567"))
    t.expect("+15551234567 vs 5551234567",    phoneMatches("+15551234567", "5551234567"))
    t.expect("(555) 123-4567 vs +15551234567", phoneMatches("(555) 123-4567", "+15551234567"))
    t.expect("555-123-4567 vs 5551234567",    phoneMatches("555-123-4567", "5551234567"))
}

t.suite("phoneMatches — different numbers") {
    t.expect("+15551234567 != +15559999999",  !phoneMatches("+15551234567", "+15559999999"))
    t.expect("555-1234 != 555-9999",          !phoneMatches("555-1234", "555-9999"))
}

t.suite("phoneMatches — email addresses") {
    t.expect("same email matches",             phoneMatches("user@example.com", "user@example.com"))
    t.expect("email is case-insensitive",      phoneMatches("USER@EXAMPLE.COM", "user@example.com"))
    t.expect("different emails don't match",   !phoneMatches("alice@x.com", "bob@x.com"))
}

t.suite("phoneMatches — short/partial (should not match)") {
    t.expect("4-digit fragment doesn't match full", !phoneMatches("1234", "+15551234567"))
}

// MARK: - formatPhone

t.suite("formatPhone — US formatting") {
    t.expect("+15551234567 → (555) 123-4567",  formatPhone("+15551234567") == "(555) 123-4567")
    t.expect("5551234567 → (555) 123-4567",    formatPhone("5551234567") == "(555) 123-4567")
    t.expect("15551234567 → (555) 123-4567",   formatPhone("15551234567") == "(555) 123-4567")
}

t.suite("formatPhone — non-US pass-through") {
    t.expect("international number unchanged", formatPhone("+44 20 7946 0958") == "+44 20 7946 0958")
    t.expect("email unchanged",                formatPhone("user@example.com") == "user@example.com")
}

// MARK: - resolveSendTarget

let alice   = MessageContact(name: "Alice Smith",   phones: ["+15551234567"], emails: ["alice@example.com"])
let bob     = MessageContact(name: "Bob Jones",     phones: ["(555) 999-8888"], emails: [])
let charlie = MessageContact(name: "Charlie Brown", phones: [], emails: ["cbrown@peanuts.com"])

let allContacts = [alice, bob, charlie]

t.suite("resolveSendTarget — direct phone input") {
    let r = resolveSendTarget("5551234567", contacts: allContacts)
    t.expect("address normalised to E.164",    r?.address == "+15551234567")
    t.expect("name is formatted phone",        r?.name == "(555) 123-4567")
}

t.suite("resolveSendTarget — direct email input") {
    let r = resolveSendTarget("new@person.com", contacts: allContacts)
    t.expect("address is the email",           r?.address == "new@person.com")
    t.expect("name is the email",              r?.name == "new@person.com")
}

t.suite("resolveSendTarget — fuzzy name match") {
    let r = resolveSendTarget("alice", contacts: allContacts)
    t.expect("finds Alice Smith",              r?.name == "Alice Smith")
    t.expect("address is her phone",           r?.address == "+15551234567")
}

let noAddress = MessageContact(name: "Dana White", phones: [], emails: [])

t.suite("resolveSendTarget — no match") {
    t.expect("unknown name returns nil",          resolveSendTarget("xyzzy", contacts: allContacts) == nil)
    t.expect("contact with no phone or email",    resolveSendTarget("Dana", contacts: [noAddress]) == nil)
    t.expect("charlie found via email",           resolveSendTarget("Charlie", contacts: allContacts)?.address == "cbrown@peanuts.com")
}

t.summary()
