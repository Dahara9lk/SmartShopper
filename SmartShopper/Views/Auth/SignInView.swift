//
//  SignInView.swift
//  SmartShopper
//
//  Figma S26 "Welcome back": email + password, Keep list in sync, Forgot Password,
//  "Fast Biometrics" Face ID sign-in, Sign in with Apple.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var mode: AuthMode
    @Binding var showAppleInfo: Bool

    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var showForgotPassword = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Welcome back")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Sign in to sync your smart lists, pantry alerts, and family shares.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            CapsuleSegment(options: ["Sign In", "Create Account"],
                           selection: Binding(get: { 0 }, set: { if $0 == 1 { mode = .createAccount } }))

            VStack(spacing: 14) {
                LabeledField(label: "Apple ID or Email", icon: "envelope.fill", placeholder: "sarah.jenkins@icloud.com",
                             text: $viewModel.email, keyboard: .emailAddress, contentType: .username,
                             showError: viewModel.didTrySubmit && !viewModel.emailIsValid,
                             errorText: "Enter a valid email address.")
                LabeledField(label: "Master Password", icon: "lock.fill", placeholder: "Your password",
                             text: $viewModel.password, contentType: .password,
                             isSecure: true, showSecure: $viewModel.showPassword)
            }
            .cardStyle()

            HStack {
                Button {
                    viewModel.keepListInSync.toggle()
                } label: {
                    Label("Keep list in sync", systemImage: viewModel.keepListInSync ? "checkmark.square.fill" : "square")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.keepListInSync ? Color.brandPrimary : Color.textSecondary)
                }
                .accessibilityValue(viewModel.keepListInSync ? "On" : "Off")
                Spacer()
                Button("Forgot Password?") {
                    viewModel.resetEmail = viewModel.email
                    viewModel.resetMessage = nil
                    showForgotPassword = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(title: "Sign In", trailingArrow: true, isLoading: viewModel.isLoading) {
                Task { await viewModel.signIn(store: store, settings: settings) }
            }

            // Face ID sign-in only appears after a password sign-in was saved
            if viewModel.hasSavedLogin {
                OrDivider(text: "FAST BIOMETRICS")
                HStack(spacing: 12) {
                    IconCircle(systemName: "faceid", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Face ID").font(.headline)
                            Pill(text: "ACTIVE", background: .brandMint)
                        }
                        Text("Instantly unlock your saved account")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.signInWithFaceID(store: store) }
                    } label: {
                        Label("Scan", systemImage: "dot.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Sign in with Face ID")
                }
                .cardStyle()
            }

            DarkButton(title: "Sign in with Apple") { showAppleInfo = true }

            if store.isDemoMode {
                InfoBanner(icon: "externaldrive.fill",
                           title: "Demo mode",
                           message: "Firebase isn't set up yet, so accounts are saved on this device only. Add GoogleService-Info.plist to use the cloud.",
                           color: .warningOrange, background: .warningSoft)
            }

            TermsText(verb: "signing in")
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
                .presentationDetents([.medium])
        }
    }

    private var forgotPasswordSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter the email you signed up with. We'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                LabeledField(label: "Email", icon: "envelope.fill", placeholder: "you@example.com",
                             text: $viewModel.resetEmail, keyboard: .emailAddress, contentType: .emailAddress)
                if let message = viewModel.resetMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.brandPrimary)
                }
                PrimaryButton(title: "Send Reset Link", icon: "paperplane.fill") {
                    Task { await viewModel.sendReset(store: store) }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showForgotPassword = false }
                }
            }
        }
    }
}
