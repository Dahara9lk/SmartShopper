//
//  AuthContainerView.swift
//  SmartShopper
//
//  Holds the Sign In / Create Account forms and switches between them.
//

import SwiftUI

enum AuthMode {
    case signIn
    case createAccount
}

struct AuthContainerView: View {
    @State var startMode: AuthMode
    @StateObject private var viewModel = AuthViewModel()
    @State private var showAppleInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch startMode {
                case .signIn:
                    SignInView(viewModel: viewModel, mode: $startMode, showAppleInfo: $showAppleInfo)
                case .createAccount:
                    CreateAccountView(viewModel: viewModel, mode: $startMode, showAppleInfo: $showAppleInfo)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)            // keeps forms readable on iPad
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(startMode == .signIn ? "Sign In" : "Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut, value: startMode)
        .alert("Sign in with Apple", isPresented: $showAppleInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in with Apple needs a paid Apple Developer account, so this student build uses email and password with Firebase Authentication.")
        }
    }
}

/// Terms line under the forms.
struct TermsText: View {
    var verb = "continuing"

    var body: some View {
        (Text("By \(verb), you agree to SmartShopper's ")
         + Text("Terms of Service").underline()
         + Text(" & ")
         + Text("Privacy Policy").underline()
         + Text("."))
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
    }
}

/// "—— OR SIGN UP WITH EMAIL ——"
struct OrDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.separatorLine).frame(height: 1)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.textSecondary)
                .fixedSize()
            Rectangle().fill(Color.separatorLine).frame(height: 1)
        }
    }
}

/// Red error box under a form.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .foregroundStyle(Color.dangerRed)
        .padding(12)
        .background(Color.dangerSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
