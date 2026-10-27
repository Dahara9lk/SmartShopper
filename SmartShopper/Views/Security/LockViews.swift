//
//  LockViews.swift
//  SmartShopper
//
//  The app lock screens:
//    S9  Face ID for SmartShopper (prompt card)
//    S7  Face ID Not Recognized + 6-digit passcode keypad
//    S24 SmartShopper Disabled (lockout countdown)
//

import SwiftUI

/// Picks the right lock screen.
struct LockContainerView: View {
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            switch security.screen {
            case .faceID:
                FaceIDPromptView()
            case .passcode:
                PasscodeView()
            case .lockedOut:
                LockoutView()
            }
        }
        .animation(.easeInOut, value: security.screen)
    }
}

// MARK: - S9 Face ID prompt

struct FaceIDPromptView: View {
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 92, height: 92)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(10)
                    .background(Color.brandMintSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .accessibilityHidden(true)

                Text("\(security.biometryName) for SmartShopper")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Use \(security.biometryName) to securely authenticate and access your shared grocery lists and saved commute routes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                if security.isVerifying {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Verifying biometric signature...")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.surfaceMuted)
                    .clipShape(Capsule())
                } else {
                    PrimaryButton(title: "Unlock with \(security.biometryName)", icon: "faceid") {
                        Task { await security.tryFaceID() }
                    }
                }

                SecondaryButton(title: "Authenticate with Passcode", icon: "key.fill",
                                background: .infoSoft, foreground: .infoBlue) {
                    security.screen = .passcode
                }

                Button("Cancel & Sign Out") {
                    security.signOutReset()
                    store.signOut()
                }
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

                Label("Secured by Apple Secure Enclave & Biometrics", systemImage: "lock.shield")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(24)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .padding(.horizontal, 28)
            .frame(maxWidth: 480)
        }
        .task {
            // Ask for Face ID straight away when the lock appears
            if !security.isVerifying {
                await security.tryFaceID()
            }
        }
    }
}

// MARK: - S7 Passcode

struct PasscodeView: View {
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "faceid")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.dangerRed)
                    .frame(width: 76, height: 76)
                    .background(Color.dangerSoft)
                    .clipShape(Circle())
                if security.faceIDFailed {
                    Image(systemName: "exclamationmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.dangerRed)
                        .clipShape(Circle())
                }
            }
            .accessibilityHidden(true)

            Text(security.faceIDFailed ? "Face ID Not Recognized" : "Enter Passcode")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.textPrimary)
            Text("Enter your 6-digit SmartShopper passcode to continue.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            if let message = security.message {
                Label(message, systemImage: "exclamationmark.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(Color.dangerRed)
                    .multilineTextAlignment(.center)
            }

            PasscodeDots(count: security.enteredCode.count, total: security.passcodeLength)

            Button {
                Task { await security.tryFaceID() }
            } label: {
                Label("Try \(security.biometryName) Again", systemImage: "faceid")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.brandMintSoft)
                    .clipShape(Capsule())
            }

            NumberKeypad(onDigit: { security.tapDigit($0) },
                         onDelete: { security.deleteDigit() },
                         leftTitle: "Forgot\nPasscode?",
                         onLeft: {
                             security.signOutReset()
                             store.signOut()
                         })

            Button("Cancel & Return to Sign In") {
                security.signOutReset()
                store.signOut()
            }
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)

            Label("Protected by Apple Secure Enclave", systemImage: "checkmark.shield.fill")
                .font(.caption2)
                .foregroundStyle(Color.brandPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.surfaceMuted)
                .clipShape(Capsule())
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
    }
}

/// ●●●○○○
struct PasscodeDots: View {
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.dangerRed : Color.surfaceMuted)
                    .frame(width: 14, height: 14)
            }
        }
        .animation(.easeOut(duration: 0.1), value: count)
        .accessibilityElement()
        .accessibilityLabel("\(count) of \(total) digits entered")
    }
}

/// 3 x 4 phone keypad.
struct NumberKeypad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    var leftTitle: String? = nil
    var onLeft: (() -> Void)? = nil

    private let letters = ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(1...9, id: \.self) { number in
                key(number: "\(number)", letters: letters[number - 1])
            }
            // bottom row: Forgot | 0 | delete
            Button {
                onLeft?()
            } label: {
                Text(leftTitle ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 72, height: 72)
            }
            .disabled(onLeft == nil)

            key(number: "0", letters: "")

            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.title3)
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 72, height: 72)
            }
            .accessibilityLabel("Delete")
        }
        .frame(maxWidth: 300)
    }

    private func key(number: String, letters: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onDigit(number)
        } label: {
            VStack(spacing: 0) {
                Text(number)
                    .font(.title.weight(.medium))
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                }
            }
            .foregroundStyle(Color.textPrimary)
            .frame(width: 72, height: 72)
            .background(Color.surfaceMuted)
            .clipShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(number)
    }
}

// MARK: - S24 Lockout

struct LockoutView: View {
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.dangerRed)
                    .frame(width: 84, height: 84)
                    .background(Color.dangerSoft)
                    .clipShape(Circle())
                    .padding(.top, 32)
                    .accessibilityHidden(true)

                Text("SmartShopper Disabled")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Too many failed attempts. For your shopping list and payment privacy, authentication is suspended.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    (Text("Try again in ").foregroundColor(.textSecondary)
                     + Text("\(security.lockoutSecondsLeft)s").foregroundColor(.dangerRed).bold())
                        .font(.title3)
                    ProgressView(value: security.lockoutProgress)
                        .tint(.dangerRed)
                    Label("Secure hardware cooldown in progress", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                .cardStyle()
                .accessibilityElement(children: .combine)

                lockoutCard(icon: "arrow.counterclockwise.circle.fill",
                            title: "Forgot your passcode?",
                            text: "Sign in again with your email and password to reset access.",
                            link: "Reset Passcode with Password")

                lockoutCard(icon: "person.badge.key.fill",
                            title: "Sign in with Master Key",
                            text: "Use your account password to bypass the lock on this device.",
                            link: "Use Password Sign-In")

                VStack(alignment: .leading, spacing: 6) {
                    Label("APPLE SECURE ENCLAVE PROTECTION", systemImage: "checkmark.shield.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.brandPrimary)
                    Text("Rate limiting is active. Another failed attempt after this cooldown locks the app for 5 minutes.")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))

                PrimaryButton(title: "Passcode Locked", icon: "lock.fill", isEnabled: false) {}

                Label("Shared family lists and cart sync remain safe & intact.", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private func lockoutCard(icon: String, title: String, text: String, link: String) -> some View {
        Button {
            // Both options: sign out so the user can sign in with their password again
            security.signOutReset()
            store.signOut()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                IconCircle(systemName: icon, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(Color.textPrimary)
                    Text(text).font(.footnote).foregroundStyle(Color.textSecondary)
                    Text(link + " →")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Passcode setup sheet (after switching Face ID on)

struct PasscodeSetupView: View {
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var first = ""
    @State private var second = ""
    @State private var isConfirming = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text(isConfirming ? "Confirm your passcode" : "Create a 6-digit passcode")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Used when Face ID doesn't recognise you.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                PasscodeDots(count: isConfirming ? second.count : first.count, total: 6)
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.dangerRed)
                        .multilineTextAlignment(.center)
                }
                NumberKeypad(onDigit: add, onDelete: removeLast)
                Spacer()
            }
            .padding(24)
            .navigationTitle("App Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // No passcode = Face ID lock can't be used
                        if !PasscodeStore.hasPasscode {
                            settings.faceIDEnabled = false
                        }
                        security.showPasscodeSetup = false
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func add(_ digit: String) {
        if isConfirming {
            guard second.count < 6 else { return }
            second += digit
            if second.count == 6 {
                if let problem = security.savePasscode(first, confirm: second) {
                    error = problem
                    first = ""
                    second = ""
                    isConfirming = false
                } else {
                    dismiss()
                }
            }
        } else {
            guard first.count < 6 else { return }
            first += digit
            if first.count == 6 {
                if Validator.isValidPasscode(first) {
                    error = nil
                    isConfirming = true
                } else {
                    error = "Use 6 digits that are not all the same or in order."
                    first = ""
                }
            }
        }
    }

    private func removeLast() {
        if isConfirming {
            if !second.isEmpty { second.removeLast() }
        } else if !first.isEmpty {
            first.removeLast()
        }
    }
}
