// TextErrors.swift
//
// Domain error types for text-cli.

import Foundation

public enum TextError: Error, LocalizedError {
    case sendFailed(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .sendFailed(let m): return "Send failed: \(m)"
        case .notFound(let q):   return "Not found: \(q)"
        }
    }
}
