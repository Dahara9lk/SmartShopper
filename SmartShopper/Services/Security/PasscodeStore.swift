//
//  PasscodeStore.swift
//  SmartShopper

//  The 6-digit app passcode (fallback when Face ID fails).
//  We never store the passcode itself; only its SHA-256 hash, inside the Keychain.


import Foundation
import CryptoKit

enum PasscodeStore {

    private static let key = "app.passcode.hash"

    static var hasPasscode: Bool { KeychainHelper.read(key) != nil }

    static func save(_ passcode: String) {
        KeychainHelper.save(hash(passcode), for: key)
    }

    static func check(_ passcode: String) -> Bool {
        guard let saved = KeychainHelper.read(key) else { return false }
        return saved == hash(passcode)
    }

    static func remove() {
        KeychainHelper.delete(key)
    }

// SHA-256 as a hex string.
    static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Counts wrong passcode tries and decides when to lock the app (Figma S24 "SmartShopper Disabled").
// A plain struct so it can be unit tested without any UI.
struct PasscodeAttemptTracker {
    let maxAttempts: Int
    let lockoutSeconds: Int
    private(set) var attemptsLeft: Int
    
// How many times the user has been locked out each lockout is longer.
    private(set) var lockoutCount = 0

    init(maxAttempts: Int = 3, lockoutSeconds: Int = 60) {
        self.maxAttempts = maxAttempts
        self.lockoutSeconds = lockoutSeconds
        self.attemptsLeft = maxAttempts
    }

// Call after a wrong passcode. Returns the lockout length in seconds, or nil if not locked yet.
    mutating func registerFailure() -> Int? {
        attemptsLeft -= 1
        if attemptsLeft <= 0 {
            lockoutCount += 1
            attemptsLeft = maxAttempts
            
// 60 s the first time, 5 minutes after that (matches the Figma text)
            return lockoutCount == 1 ? lockoutSeconds : 300
        }
        return nil
    }

// Call after a correct passcode or Face ID.
    mutating func reset() {
        attemptsLeft = maxAttempts
        lockoutCount = 0
    }
}
