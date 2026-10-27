//
//  BiometricService.swift
//  SmartShopper
//
//  Face ID / Touch ID using Apple's LocalAuthentication framework.
//  The face data never leaves the Secure Enclave - the app only gets "yes" or "no".
//
//  Simulator: Features > Face ID > Enrolled, then
//             Features > Face ID > Matching Face / Non-matching Face
//

import Foundation
import LocalAuthentication

enum BiometricResult: Equatable {
    case success
    case failed            // face not recognised
    case cancelled         // user tapped Cancel
    case fallback          // user tapped "Use Passcode"
    case unavailable(String)
}

struct BiometricService {

    /// "Face ID", "Touch ID" or "Biometrics"
    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Face ID"
        }
    }

    /// true when the phone has Face ID set up.
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Shows the system Face ID prompt and waits for the result.
    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable(error?.localizedDescription ?? "Face ID is not set up on this device.")
        }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                      localizedReason: reason)
            return ok ? .success : .failed
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel:
                return .cancelled
            case .userFallback:
                return .fallback
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}
