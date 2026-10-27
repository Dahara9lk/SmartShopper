//
//  LocalAuthService.swift
//  SmartShopper
//
//  DEMO MODE ONLY. Used when Firebase is not set up yet (no GoogleService-Info.plist)
//  and inside unit tests. Accounts are kept in UserDefaults on this device only.
//

import Foundation

final class LocalAuthService: AuthServiceProtocol {

    private let defaults: UserDefaults
    private let accountsKey = "demo.accounts"      // [email: [password, uid]]
    private let currentKey = "demo.currentUser"    // uid
    private let currentEmailKey = "demo.currentEmail"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentUserId: String? { defaults.string(forKey: currentKey) }
    var currentEmail: String? { defaults.string(forKey: currentEmailKey) }

    private var accounts: [String: [String]] {
        get { defaults.dictionary(forKey: accountsKey) as? [String: [String]] ?? [:] }
        set { defaults.set(newValue, forKey: accountsKey) }
    }

    func signUp(email: String, password: String) async throws -> String {
        let key = email.lowercased()
        guard Validator.isValidEmail(key) else { throw AuthError.invalidEmail }
        guard Validator.isValidPassword(password) else { throw AuthError.weakPassword }
        guard accounts[key] == nil else { throw AuthError.emailInUse }
        let uid = UUID().uuidString
        accounts[key] = [password, uid]
        saveCurrent(uid: uid, email: key)
        return uid
    }

    func signIn(email: String, password: String) async throws -> String {
        let key = email.lowercased()
        guard let saved = accounts[key], saved.count == 2, saved[0] == password else {
            throw AuthError.wrongCredentials
        }
        saveCurrent(uid: saved[1], email: key)
        return saved[1]
    }

    func sendPasswordReset(email: String) async throws {
        // Nothing to send in demo mode - just pretend it worked.
    }

    func signOut() throws {
        defaults.removeObject(forKey: currentKey)
        defaults.removeObject(forKey: currentEmailKey)
    }

    private func saveCurrent(uid: String, email: String) {
        defaults.set(uid, forKey: currentKey)
        defaults.set(email, forKey: currentEmailKey)
    }
}
