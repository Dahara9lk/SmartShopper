//
//  SecurityTests.swift
//  SmartShopperTests
//
//  Passcode attempts / lockout logic and passcode hashing.
//

import Testing
@testable import SmartShopper

@Suite("App lock and passcode")
struct SecurityTests {

    @Test("Two wrong passcodes do not lock, the third locks for 60 seconds")
    func lockoutAfterThreeFailures() {
        var tracker = PasscodeAttemptTracker(maxAttempts: 3, lockoutSeconds: 60)
        #expect(tracker.registerFailure() == nil)
        #expect(tracker.attemptsLeft == 2)
        #expect(tracker.registerFailure() == nil)
        #expect(tracker.attemptsLeft == 1)
        #expect(tracker.registerFailure() == 60)
        #expect(tracker.attemptsLeft == 3)          // counter resets after the lockout starts
    }

    @Test("A second lockout is longer (5 minutes)")
    func secondLockoutIsLonger() {
        var tracker = PasscodeAttemptTracker()
        _ = tracker.registerFailure()
        _ = tracker.registerFailure()
        #expect(tracker.registerFailure() == 60)
        _ = tracker.registerFailure()
        _ = tracker.registerFailure()
        #expect(tracker.registerFailure() == 300)
    }

    @Test("Reset after a correct passcode clears everything")
    func resetClearsAttempts() {
        var tracker = PasscodeAttemptTracker()
        _ = tracker.registerFailure()
        tracker.reset()
        #expect(tracker.attemptsLeft == 3)
        #expect(tracker.lockoutCount == 0)
    }

    @Test("Passcodes are stored as a SHA-256 hash, never as plain text")
    func hashing() {
        let hash = PasscodeStore.hash("482915")
        #expect(hash.count == 64)                 // 32 bytes as hex
        #expect(hash != "482915")
        #expect(hash == PasscodeStore.hash("482915"))
        #expect(hash != PasscodeStore.hash("482916"))
    }

    @Test("Saving and checking a passcode through the Keychain")
    func keychainRoundTrip() {
        PasscodeStore.save("482915")
        #expect(PasscodeStore.hasPasscode)
        #expect(PasscodeStore.check("482915"))
        #expect(!PasscodeStore.check("000000"))
        PasscodeStore.remove()
        #expect(!PasscodeStore.hasPasscode)
    }
}

@Suite("Quiet hours")
struct QuietHoursTests {

    @Test("A window that crosses midnight (10 PM - 7 AM)", arguments: [
        (22, true), (23, true), (0, true), (6, true), (7, false), (12, false), (21, false)
    ])
    func overnightWindow(hour: Int, expectedQuiet: Bool) {
        #expect(QuietHours.isQuiet(hour: hour, start: 22, end: 7) == expectedQuiet)
    }

    @Test("A daytime window (1 PM - 3 PM)")
    func daytimeWindow() {
        #expect(QuietHours.isQuiet(hour: 13, start: 13, end: 15))
        #expect(!QuietHours.isQuiet(hour: 15, start: 13, end: 15))
    }

    @Test("Urgent items get through only when the override is on")
    func urgentOverride() {
        #expect(!QuietHours.shouldDeliver(hour: 23, quietOn: true, start: 22, end: 7, isUrgent: false, urgentOverride: true))
        #expect(QuietHours.shouldDeliver(hour: 23, quietOn: true, start: 22, end: 7, isUrgent: true, urgentOverride: true))
        #expect(!QuietHours.shouldDeliver(hour: 23, quietOn: true, start: 22, end: 7, isUrgent: true, urgentOverride: false))
        #expect(QuietHours.shouldDeliver(hour: 23, quietOn: false, start: 22, end: 7, isUrgent: false, urgentOverride: false))
    }
}
