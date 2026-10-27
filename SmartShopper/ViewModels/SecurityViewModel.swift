//
//  SecurityViewModel.swift
//  SmartShopper
//
//  Controls the app lock (Figma S9 Face ID prompt, S7 passcode, S24 lockout).
//
//  When Face ID is switched on:
//   - the app locks on launch and when it comes back from the background
//     (after the "Lock Timeout" in settings)
//   - Face ID unlocks it; if Face ID fails the 6-digit app passcode is used
//   - 3 wrong passcodes = locked for 60 seconds, then 5 minutes
//

import Foundation
import Combine
import SwiftUI


@MainActor
final class SecurityViewModel: ObservableObject {

    enum LockScreen: Equatable {
        case faceID        // S9
        case passcode      // S7
        case lockedOut     // S24
    }

    @Published var isLocked = false
    @Published var screen: LockScreen = .faceID
    @Published var enteredCode = ""
    @Published var message: String?
    @Published var faceIDFailed = false
    @Published var isVerifying = false
    @Published private(set) var lockoutSecondsLeft = 0
    @Published private(set) var lockoutTotalSeconds = 60
    @Published private(set) var attemptsLeft = 3
    /// Shows the "Create a passcode" sheet after Face ID is switched on.
    @Published var showPasscodeSetup = false

    private let settings: SettingsStore
    private let biometrics = BiometricService()
    private var tracker = PasscodeAttemptTracker()
    private var backgroundDate: Date?
    private var lockoutTask: Task<Void, Never>?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var biometryName: String { biometrics.biometryName }
    var isBiometryAvailable: Bool { biometrics.isAvailable }
    var passcodeLength: Int { 6 }

    // MARK: When to lock

    /// App launched.
    func lockOnLaunch() {
        if settings.faceIDEnabled && PasscodeStore.hasPasscode {
            lock()
        }
    }

    /// App went to the background - remember when.
    func appDidEnterBackground() {
        backgroundDate = Date()
    }

    /// App came back - lock again if the timeout has passed.
    func appDidBecomeActive() {
        guard settings.faceIDEnabled, PasscodeStore.hasPasscode, !isLocked, let backgroundDate else { return }
        let seconds = Int(Date().timeIntervalSince(backgroundDate))
        if seconds >= settings.lockTimeoutSeconds {
            lock()
        }
        self.backgroundDate = nil
    }

    func lock() {
        isLocked = true
        enteredCode = ""
        message = nil
        faceIDFailed = false
        screen = lockoutSecondsLeft > 0 ? .lockedOut : .faceID
    }

    private func unlock() {
        tracker.reset()
        attemptsLeft = tracker.attemptsLeft
        isLocked = false
        enteredCode = ""
        message = nil
        faceIDFailed = false
    }

    // MARK: Face ID

    func tryFaceID() async {
        guard screen != .lockedOut else { return }
        isVerifying = true
        let result = await biometrics.authenticate(reason: "Unlock your SmartShopper lists")
        isVerifying = false
        switch result {
        case .success:
            unlock()
        case .fallback:
            screen = .passcode
        case .cancelled:
            break
        case .failed:
            faceIDFailed = true
            screen = .passcode
        case .unavailable(let reason):
            message = reason
            screen = .passcode
        }
    }

    // MARK: Passcode keypad

    func tapDigit(_ digit: String) {
        guard screen == .passcode, enteredCode.count < passcodeLength else { return }
        enteredCode += digit
        if enteredCode.count == passcodeLength {
            checkPasscode()
        }
    }

    func deleteDigit() {
        guard !enteredCode.isEmpty else { return }
        enteredCode.removeLast()
    }

    private func checkPasscode() {
        if PasscodeStore.check(enteredCode) {
            unlock()
            return
        }
        enteredCode = ""
        if let lockout = tracker.registerFailure() {
            startLockout(seconds: lockout)
        } else {
            attemptsLeft = tracker.attemptsLeft
            message = "Incorrect passcode. \(attemptsLeft) attempt\(attemptsLeft == 1 ? "" : "s") remaining before lockout"
        }
    }

    private func startLockout(seconds: Int) {
        lockoutTotalSeconds = seconds
        lockoutSecondsLeft = seconds
        screen = .lockedOut
        attemptsLeft = tracker.attemptsLeft
        message = nil
        lockoutTask?.cancel()
        lockoutTask = Task { [weak self] in
            while let self, self.lockoutSecondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.lockoutSecondsLeft -= 1
            }
            self?.screen = .passcode
        }
    }

    /// 0...1 for the red countdown bar.
    var lockoutProgress: Double {
        guard lockoutTotalSeconds > 0 else { return 0 }
        return Double(lockoutSecondsLeft) / Double(lockoutTotalSeconds)
    }

    // MARK: Settings actions

    /// Face ID switch in Profile. Checks Face ID first, then asks for a passcode if there is none.
    func setFaceIDEnabled(_ enabled: Bool) async {
        if !enabled {
            settings.faceIDEnabled = false
            return
        }
        let result = await biometrics.authenticate(reason: "Turn on Face ID for SmartShopper")
        if result == .success {
            settings.faceIDEnabled = true
            if !PasscodeStore.hasPasscode {
                showPasscodeSetup = true
            }
        } else {
            settings.faceIDEnabled = false
            if case .unavailable(let reason) = result {
                message = reason
            }
        }
    }

    /// Saves a new passcode from the setup sheet. Returns an error message or nil when OK.
    func savePasscode(_ code: String, confirm: String) -> String? {
        guard Validator.isValidPasscode(code) else {
            return "Use 6 digits that are not all the same or in order."
        }
        guard code == confirm else { return "Passcodes don't match. Try again." }
        PasscodeStore.save(code)
        showPasscodeSetup = false
        return nil
    }

    /// "Reset Face ID for SmartShopper" - turns the lock off and removes the passcode.
    func resetSecurity() {
        settings.faceIDEnabled = false
        PasscodeStore.remove()
        unlock()
    }

    /// Used by "Cancel & Return to Sign In" and the lockout screen.
    func signOutReset() {
        lockoutTask?.cancel()
        lockoutSecondsLeft = 0
        unlock()
    }

    /// Asks for Face ID before showing something private (Family list, route).
    func confirmIdentity(reason: String) async -> Bool {
        guard settings.faceIDEnabled else { return true }
        return await biometrics.authenticate(reason: reason) == .success
    }
}
