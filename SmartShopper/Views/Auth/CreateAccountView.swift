//
//  CreateAccountView.swift
//  SmartShopper
//
//  Figma S1 "Join SmartShopper": name, email, password with strength meter,
//  household setup (new circle or invite code), Face ID switch.
//

import SwiftUI

struct CreateAccountView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var mode: AuthMode
    @Binding var showAppleInfo: Bool

    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(spacing: 20) {
            header

            DarkButton(title: "Continue with Apple") { showAppleInfo = true }

            OrDivider(text: "OR SIGN UP WITH EMAIL")

            accountCard
            householdCard

            InfoBanner(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                       title: "On-Device Route Mapping",
                       message: "Location stays private and never leaves your iPhone.")

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error)
            }

            PrimaryButton(title: "Create Account & Continue",
                          trailingArrow: true,
                          isLoading: viewModel.isLoading) {
                Task { await viewModel.createAccount(store: store, security: security, settings: settings) }
            }

            TermsText()

            Button {
                mode = .signIn
            } label: {
                (Text("Already have an account? ").foregroundColor(.textSecondary)
                 + Text("Sign In ›").foregroundColor(.brandPrimary).bold())
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Parts

    private var header: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AppLogoBadge(size: 64)
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.warningOrange)
                    .padding(5)
                    .background(Color.surface)
                    .clipShape(Circle())
                    .offset(x: 6, y: 6)
            }
            Text("Join SmartShopper")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.textPrimary)
            Text("Optimize grocery stops along your daily route and sync shared family lists in real-time.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var accountCard: some View {
        VStack(spacing: 16) {
            LabeledField(label: "Full Name", icon: "person.fill", placeholder: "Sarah Jenkins",
                         text: $viewModel.fullName, contentType: .name,
                         showError: viewModel.didTrySubmit && !viewModel.nameIsValid,
                         errorText: "Enter at least 2 letters.")

            LabeledField(label: "Email Address", icon: "envelope.fill", placeholder: "sarah.jenkins@icloud.com",
                         text: $viewModel.email, keyboard: .emailAddress, contentType: .emailAddress,
                         showError: viewModel.didTrySubmit && !viewModel.emailIsValid,
                         errorText: "Enter a valid email address.")

            VStack(alignment: .leading, spacing: 8) {
                LabeledField(label: "Create Password", icon: "lock.fill", placeholder: "At least 8 characters",
                             text: $viewModel.password, contentType: .newPassword,
                             isSecure: true, showSecure: $viewModel.showPassword,
                             trailingNote: viewModel.passwordStrength.title,
                             trailingNoteColor: strengthColor,
                             showError: viewModel.didTrySubmit && !viewModel.passwordIsValid)
                // 4-bar strength meter
                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { bar in
                        Capsule()
                            .fill(bar <= viewModel.passwordStrength.rawValue ? strengthColor : Color.surfaceMuted)
                            .frame(height: 5)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Password strength")
                .accessibilityValue(viewModel.passwordStrength.title)

                Label("At least 8 chars with symbols & numbers",
                      systemImage: viewModel.passwordIsValid ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(viewModel.passwordIsValid ? Color.brandPrimary : Color.textSecondary)
            }
        }
        .cardStyle()
    }

    private var strengthColor: Color {
        switch viewModel.passwordStrength {
        case .empty, .weak: return .dangerRed
        case .fair: return .warningOrange
        case .good, .strong: return .brandPrimary
        }
    }

    private var householdCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(Color.brandPrimary)
                Text("Household Setup")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Pill(text: "Step 1 of 2", background: .brandMint)
            }

            CapsuleSegment(options: ["New Circle", "Enter Invite Code"],
                           selection: Binding(get: { viewModel.householdMode.rawValue },
                                              set: { viewModel.householdMode = AuthViewModel.HouseholdMode(rawValue: $0) ?? .newCircle }))

            if viewModel.householdMode == .newCircle {
                LabeledField(label: "Household Name", icon: "house.fill", placeholder: "Jenkins Family",
                             text: $viewModel.householdName,
                             showError: viewModel.didTrySubmit && !viewModel.householdIsValid,
                             errorText: "Give your household a name.")
            } else {
                LabeledField(label: "Invite Code", icon: "qrcode", placeholder: "6-character code e.g. K7Q2MX",
                             text: $viewModel.inviteCode,
                             showError: viewModel.didTrySubmit && !viewModel.householdIsValid,
                             errorText: "Invite codes have 6 letters or numbers.")
            }

            Toggle(isOn: $viewModel.enableFaceID) {
                HStack(spacing: 12) {
                    IconCircle(systemName: "faceid", size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Face ID").font(.body.weight(.medium))
                        Text("Instant, secure unlock for your lists")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .tint(.brandPrimary)
        }
        .cardStyle()
    }
}
