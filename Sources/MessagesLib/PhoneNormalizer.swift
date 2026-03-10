// PhoneNormalizer.swift
//
// Phone number normalization and matching logic.
// No framework dependencies — pure Swift, fully unit testable.

import Foundation

public struct MessageContact {
    public let name:   String
    public let phones: [String]   // raw strings from Contacts
    public let emails: [String]

    public init(name: String, phones: [String], emails: [String]) {
        self.name   = name
        self.phones = phones
        self.emails = emails
    }
}

/// Normalize a phone number to E.164-ish format (+1XXXXXXXXXX for US numbers).
/// Returns the input unchanged if it can't be normalized.
public func normalizePhone(_ s: String) -> String {
    // Email addresses pass through untouched
    if s.contains("@") { return s }

    let digits = s.filter { $0.isNumber }
    if digits.count == 10 { return "+1" + digits }
    if digits.count == 11 && digits.hasPrefix("1") { return "+" + digits }
    // Already has + prefix — strip formatting but keep the +
    if s.hasPrefix("+") { return "+" + digits }
    return s
}

/// Returns true if two identifiers refer to the same phone number.
/// Compares the last 10 digits (handles +1 vs no-prefix differences).
/// For non-phone identifiers (email), falls back to case-insensitive equality.
public func phoneMatches(_ a: String, _ b: String) -> Bool {
    if a.contains("@") || b.contains("@") {
        return a.lowercased() == b.lowercased()
    }
    let da = a.filter { $0.isNumber }
    let db = b.filter { $0.isNumber }
    guard !da.isEmpty, !db.isEmpty else { return a == b }
    return da.suffix(10) == db.suffix(10) && da.count >= 10
}

/// Format a US phone number for display: "(555) 123-4567"
/// Returns the input unchanged if it can't be formatted.
public func formatPhone(_ s: String) -> String {
    let digits = s.filter { $0.isNumber }
    let ten: Substring
    if digits.count == 11 && digits.hasPrefix("1") {
        ten = digits.dropFirst()
    } else if digits.count == 10 {
        ten = digits[digits.startIndex...]
    } else {
        return s
    }
    let area = ten.prefix(3)
    let mid  = ten.dropFirst(3).prefix(3)
    let last = ten.dropFirst(6)
    return "(\(area)) \(mid)-\(last)"
}

/// Given a chat identifier (phone number or email from chat.db),
/// return the display name from the contacts list.
/// Returns nil if no match found.
public func resolveIdentifier(_ identifier: String,
                               contacts: [MessageContact]) -> String? {
    for contact in contacts {
        if contact.phones.contains(where: { phoneMatches($0, identifier) }) {
            return contact.name
        }
        if contact.emails.contains(where: { $0.lowercased() == identifier.lowercased() }) {
            return contact.name
        }
    }
    return nil
}

/// Find a contact's send address given a name, phone number, or email.
/// Returns `(displayName, address)` where address is what Messages.app will accept.
/// Returns nil if no contact matched and input doesn't look like a direct address.
public func resolveSendTarget(_ input: String,
                               contacts: [MessageContact]) -> (name: String, address: String)? {
    let q = input.trimmingCharacters(in: .whitespaces)

    // Direct phone number
    let digits = q.filter { $0.isNumber }
    if (digits.count == 10 || digits.count == 11) && !q.contains("@") {
        let normalized = normalizePhone(q)
        return (name: formatPhone(normalized), address: normalized)
    }

    // Direct email address
    if q.contains("@") && !q.contains(" ") {
        return (name: q, address: q)
    }

    // Fuzzy name match
    let ql = q.lowercased()
    let matched = contacts.filter { c in
        let name = c.name.lowercased()
        return name == ql || name.hasPrefix(ql) || name.contains(ql)
    }
    guard let contact = matched.first else { return nil }

    // Prefer mobile > iPhone > main > any
    let preferredLabels = ["mobile", "iphone", "main"]
    var bestPhone: String? = nil
    for label in preferredLabels {
        if let p = contact.phones.first(where: { phoneLabel($0, contact: contact, label: label) }) {
            bestPhone = p
            break
        }
    }
    let phone = bestPhone ?? contact.phones.first

    if let phone {
        return (name: contact.name, address: normalizePhone(phone))
    }
    if let email = contact.emails.first {
        return (name: contact.name, address: email)
    }
    return nil
}

// Stub — label matching is done in main.swift with CNContact label info.
// This variant matches on phone value only (used when labels aren't available).
private func phoneLabel(_ phone: String, contact: MessageContact, label: String) -> Bool {
    // Without label data we can't filter — always false so we fall through to first
    return false
}
