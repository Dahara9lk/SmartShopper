//
//  Validator.swift
//  SmartShopper

//  Form checks for Create Account / Sign In. Pure functions = easy to unit test.


import Foundation

enum PasswordStrength: Int {
    case empty = 0
    case weak = 1
    case fair = 2
    case good = 3
    case strong = 4

    var title: String {
        switch self {
        case .empty: return ""
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .good: return "Good"
        case .strong: return "Strong"
        }
    }
}

enum Validator {

    // Standard email pattern: something@something.domain
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: trimmed)
    }

    // At least 2 letters, only letters / spaces / . ' -
    
    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let letters = trimmed.filter { $0.isLetter }
        let allowed = trimmed.allSatisfy { $0.isLetter || $0 == " " || $0 == "." || $0 == "'" || $0 == "-" }
        return letters.count >= 2 && allowed
    }

    // Rule shown under the password field: 8+ chars with a letter, a number and a symbol.
    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8 && hasLetter(password) && hasNumber(password) && hasSymbol(password)
    }

    // Strength meter
    static func passwordStrength(_ password: String) -> PasswordStrength {
        if password.isEmpty { return .empty }
        var score = 0
        if password.count >= 8 { score += 1 }
        if hasLetter(password) && hasNumber(password) { score += 1 }
        if hasSymbol(password) { score += 1 }
        if password.count >= 12 || (hasUppercase(password) && hasLowercase(password)) { score += 1 }
        return PasswordStrength(rawValue: max(1, score)) ?? .weak
    }

    //Invite codes are 6 letters/numbers
    
    static func isValidInviteCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        return trimmed.count == 6 && trimmed.allSatisfy { $0.isLetter || $0.isNumber }
    }

    // App passcode: exactly 6 digits, not all the same, not 123456 / 654321
    static func isValidPasscode(_ code: String) -> Bool {
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else { return false }
        if Set(code).count == 1 { return false }
        if code == "123456" || code == "654321" { return false }
        return true
    }

// helpers
    
    private static func hasLetter(_ s: String) -> Bool { s.contains { $0.isLetter } }
    private static func hasNumber(_ s: String) -> Bool { s.contains { $0.isNumber } }
    private static func hasUppercase(_ s: String) -> Bool { s.contains { $0.isUppercase } }
    private static func hasLowercase(_ s: String) -> Bool { s.contains { $0.isLowercase } }
    private static func hasSymbol(_ s: String) -> Bool {
        s.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
    }
}
