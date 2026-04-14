// ContactsLoader.swift
//
// Load contacts from the system Contacts store for name and phone resolution.

import Foundation
import Contacts
import TextLib

let keysToFetch: [CNKeyDescriptor] = [
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
