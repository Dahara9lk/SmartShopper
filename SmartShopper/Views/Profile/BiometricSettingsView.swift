//
//  BiometricSettingsView.swift
//  SmartShopper
//
//  Face ID permissions (unlock app, protect family lists, quick auth on commute),
//  lock timeout, change passcode, reset Face ID.
//

import SwiftUI

struct BiometricSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var security: SecurityViewModel
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Explanation card
                HStack(alignment: .top, spacing: 14) {
                    IconCircle(systemName: "faceid", size: 48, filled: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Biometric Protection")
                            .font(.title3.weight(.semibold))
                        Text("Use \(security.biometryName) for rapid shopping unlock, secure family shared lists and protected commute sync.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .cardStyle()

                if !security.isBiometryAvailable {
                    InfoBanner(icon: "exclamationmark.triangle.fill", title: "\(security.biometryName) not set up",
                               message: "Simulator: Features > Face ID > Enrolled. iPhone: Settings > Face ID & Passcode.",
                               color: .warningOrange, background: .warningSoft)
                }

                SettingsGroup(title: "SmartShopper Biometric Permissions") {
                    SettingsToggleRow(icon: "lock.fill", title: "Unlock SmartShopper",
                                      subtitle: "Require \(security.biometryName) when opening the app",
                                      isOn: Binding(get: { settings.faceIDEnabled },
                                                    set: { value in Task { await security.setFaceIDEnabled(value) } }))
                    RowDivider()
                    SettingsToggleRow(icon: "person.3.fill", iconColor: .infoBlue, title: "Protect Family Shared Lists",
                                      subtitle: "Ask for \(security.biometryName) before showing the family list",
                                      isOn: $settings.protectFamilyLists)
                        .disabled(!settings.faceIDEnabled)
                    RowDivider()
                    SettingsToggleRow(icon: "location.north.line.fill", iconColor: .textPrimary, title: "Quick Auth on Commute",
                                      subtitle: "Confirm identity before starting route navigation",
                                      isOn: $settings.quickAuthOnCommute)
                        .disabled(!settings.faceIDEnabled)
                    RowDivider()
                    SettingsToggleRow(icon: "person.badge.key.fill", iconColor: .textSecondary, title: "Face ID Sign-In",
                                      subtitle: "Save your sign-in in the Keychain for one-tap login",
                                      isOn: $settings.keepSignedInWithFaceID)
                }

                SettingsGroup(title: "Lock Timeout") {
                    Picker("Require Face ID", selection: $settings.lockTimeoutSeconds) {
                        Text("Immediately").tag(0)
                        Text("After 1 minute").tag(60)
                        Text("After 5 minutes").tag(300)
                    }
                    .pickerStyle(.menu)
                    .tint(.brandPrimary)
                    .padding(14)
                }

                SettingsGroup(title: "Security & Fallback") {
                    SettingsValueRow(icon: "circle.grid.3x3.fill", iconColor: .textSecondary,
                                     title: PasscodeStore.hasPasscode ? "Change 6-Digit Passcode" : "Create 6-Digit Passcode") {
                        security.showPasscodeSetup = true
                    }
                    RowDivider()
                    SettingsValueRow(icon: "faceid", iconColor: .dangerRed, title: "Reset Face ID for SmartShopper",
                                     titleColor: .dangerRed, showChevron: false) {
                        showResetConfirm = true
                    }
                }

                Label("Face data is safely stored in the Secure Enclave on your device and is never sent to SmartShopper servers. Uses Apple's LocalAuthentication framework.",
                      systemImage: "checkmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle("Face ID & Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset Face ID?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                security.resetSecurity()
                AuthViewModel.forgetSavedLogin()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This turns off the app lock, deletes your app passcode and the saved Face ID sign-in.")
        }
    }
}
