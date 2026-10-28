//
//  FirebaseAuthService.swift
//  SmartShopper
//  Real sign up / sign in using Firebase Authentication (email + password).


import Foundation
import FirebaseAuth

final class FirebaseAuthService: AuthServiceProtocol {

    var currentUserId: String? { Auth.auth().currentUser?.uid }
    var currentEmail: String? { Auth.auth().currentUser?.email }

    func signUp(email: String, password: String) async throws -> String {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return result.user.uid
        } catch {
            throw convert(error)
        }
    }

    func signIn(email: String, password: String) async throws -> String {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user.uid
        } catch {
            throw convert(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw convert(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

// Turns a Firebase error into AuthError.
    private func convert(_ error: Error) -> AuthError {
        let nsError = error as NSError
        return AuthError.fromFirebaseCode(nsError.code, message: nsError.localizedDescription)
    }
}
