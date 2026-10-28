//
//  AuthViewModel.swift
//  SmartShopper
//
//  Form state + validation for Create Account (S1) and Sign In (S26).
//

import Foundation
import Combine


@MainActor
final class AuthViewModel: ObservableObject {

    enum HouseholdMode: Int {
        case newCircle = 0
        case joinWithCode = 1
    }

    // Create account fields
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var showPassword = false
    @Published var householdMode: HouseholdMode = .newCircle
    @Published var householdName = ""
    @Published var inviteCode = ""
    @Published var enableFaceID = true

    // Sign in extras
    @Published var keepListInSync = true
    @Published var resetEmail = ""
    @Published var resetMessage: String?

    // Status
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Fields turn red only after the user tried to submit once.
    @Published var didTrySubmit = false

    private static let savedEmailKey = "faceid.login.email"
    private static let savedPasswordKey = "faceid.login.password"

// Validation (used to show red hints and enable the button)

    var nameIsValid: Bool { Validator.isValidName(fullName) }
    var emailIsValid: Bool { Validator.isValidEmail(email) }
    var passwordIsValid: Bool { Validator.isValidPassword(password) }
    var passwordStrength: PasswordStrength { Validator.passwordStrength(password) }

    var householdIsValid: Bool {
        switch householdMode {
        case .newCircle: return householdName.trimmingCharacters(in: .whitespaces).count >= 2
        case .joinWithCode: return Validator.isValidInviteCode(inviteCode)
        }
    }

    var canCreateAccount: Bool {
        nameIsValid && emailIsValid && passwordIsValid && householdIsValid && !isLoading
    }

    var canSignIn: Bool {
        emailIsValid && !password.isEmpty && !isLoading
    }

    // true when an earlier sign-in was saved for Face ID ("Fast Biometrics" card).
    var hasSavedLogin: Bool {
        KeychainHelper.read(Self.savedEmailKey) != nil
    }

// Actions

    func createAccount(store: AppDataStore, security: SecurityViewModel, settings: SettingsStore) async {
        didTrySubmit = true
        guard canCreateAccount else {
            errorMessage = firstProblem()
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let code = householdMode == .joinWithCode ? inviteCode.uppercased() : nil
            let circleName = householdName.isEmpty ? "\(lastName()) Family" : householdName
            try await store.createAccount(name: fullName.trimmingCharacters(in: .whitespaces),
                                          email: email.trimmingCharacters(in: .whitespaces),
                                          password: password,
                                          householdName: circleName,
                                          inviteCode: code)
            saveLoginForFaceID(settings: settings)
            if enableFaceID {
                await security.setFaceIDEnabled(true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(store: AppDataStore, settings: SettingsStore) async {
        didTrySubmit = true
        guard canSignIn else {
            errorMessage = emailIsValid ? "Enter your password." : "Enter a valid email address."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await store.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            if keepListInSync {
                saveLoginForFaceID(settings: settings)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // "Face ID ; Scan" on the Sign In screen: Face ID first, then the saved login.
    func signInWithFaceID(store: AppDataStore) async {
        guard let savedEmail = KeychainHelper.read(Self.savedEmailKey),
              let savedPassword = KeychainHelper.read(Self.savedPasswordKey) else {
            errorMessage = "Sign in with your password once to enable Face ID sign-in."
            return
        }
        let result = await BiometricService().authenticate(reason: "Sign in to SmartShopper")
        guard result == .success else {
            if case .unavailable(let reason) = result { errorMessage = reason }
            return
        }
        isLoading = true
        do {
            try await store.signIn(email: savedEmail, password: savedPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func sendReset(store: AppDataStore) async {
        guard Validator.isValidEmail(resetEmail) else {
            resetMessage = "Enter a valid email address."
            return
        }
        do {
            try await store.sendPasswordReset(email: resetEmail)
            resetMessage = "Reset link sent to \(resetEmail). Check your inbox."
        } catch {
            resetMessage = error.localizedDescription
        }
    }

// Helpers

    private func saveLoginForFaceID(settings: SettingsStore) {
        guard settings.keepSignedInWithFaceID else { return }
        KeychainHelper.save(email.trimmingCharacters(in: .whitespaces).lowercased(), for: Self.savedEmailKey)
        KeychainHelper.save(password, for: Self.savedPasswordKey)
    }

    // Removes the saved login (Profile > Reset Face ID).
    static func forgetSavedLogin() {
        KeychainHelper.delete(savedEmailKey)
        KeychainHelper.delete(savedPasswordKey)
    }

    private func lastName() -> String {
        let parts = fullName.split(separator: " ")
        return parts.last.map(String.init) ?? "My"
    }

    // The first thing wrong with the form, shown as the error message.
    private func firstProblem() -> String {
        if !nameIsValid { return "Enter your full name." }
        if !emailIsValid { return "Enter a valid email address." }
        if !passwordIsValid { return "Password needs at least 8 characters with a number and a symbol." }
        if !householdIsValid {
            return householdMode == .newCircle ? "Give your household a name." : "Invite codes have 6 letters or numbers."
        }
        return "Please check the form."
    }
}
