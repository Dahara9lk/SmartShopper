//
//  AuthServiceProtocol.swift
//  SmartShopper
//
//  The app talks to "an auth service" through this protocol.
//  FirebaseAuthService is the real one; LocalAuthService is a demo version
//  used when GoogleService-Info.plist has not been added yet (and in tests).
//

import Foundation

protocol AuthServiceProtocol: AnyObject {
    /// The signed-in user's id, or nil when signed out.
    var currentUserId: String? { get }
    var currentEmail: String? { get }

    /// Creates an account and returns the new user id.
    func signUp(email: String, password: String) async throws -> String
    /// Signs in and returns the user id.
    func signIn(email: String, password: String) async throws -> String
    func sendPasswordReset(email: String) async throws
    func signOut() throws
}

/// Friendly error messages shown under the forms.
enum AuthError: LocalizedError {
    case emailInUse
    case invalidEmail
    case weakPassword
    case wrongCredentials
    case network
    case tooManyRequests
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emailInUse: return "An account already exists with this email. Try signing in."
        case .invalidEmail: return "That email address doesn't look right."
        case .weakPassword: return "Password is too weak. Use at least 8 characters with a number and a symbol."
        case .wrongCredentials: return "Email or password is incorrect."
        case .network: return "No internet connection. Please try again."
        case .tooManyRequests: return "Too many attempts. Please wait a minute and try again."
        case .unknown(let message): return message
        }
    }

    /// Converts a Firebase Auth error code (NSError.code) into an AuthError.
    /// Codes are from Firebase's AuthErrorCode list.
    static func fromFirebaseCode(_ code: Int, message: String) -> AuthError {
        switch code {
        case 17007: return .emailInUse
        case 17008: return .invalidEmail
        case 17026: return .weakPassword
        case 17004, 17009, 17011: return .wrongCredentials
        case 17020: return .network
        case 17010: return .tooManyRequests
        default: return .unknown(message)
        }
    }
}
