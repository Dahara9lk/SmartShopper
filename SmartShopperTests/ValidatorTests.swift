//
//  ValidatorTests.swift
//  SmartShopperTests
//
//  Form validation used on Create Account / Sign In (Swift Testing framework).
//

import Testing
@testable import SmartShopper

@Suite("Form validation")
struct ValidatorTests {

    @Test("Valid emails pass", arguments: ["sarah@icloud.com", "a.b+shop@nibm.lk", "test_user@mail.co.uk"])
    func validEmails(email: String) {
        #expect(Validator.isValidEmail(email))
    }

    @Test("Invalid emails fail", arguments: ["", "sarah", "sarah@", "@icloud.com", "sarah@icloud", "sa rah@icloud.com"])
    func invalidEmails(email: String) {
        #expect(!Validator.isValidEmail(email))
    }

    @Test("Names need at least two letters and no digits")
    func names() {
        #expect(Validator.isValidName("Sarah Jenkins"))
        #expect(Validator.isValidName("D'Silva"))
        #expect(!Validator.isValidName("A"))
        #expect(!Validator.isValidName("R2D2"))
        #expect(!Validator.isValidName("   "))
    }

    @Test("Password rule: 8+ chars with a letter, number and symbol")
    func passwordRule() {
        #expect(Validator.isValidPassword("GrocerySmart2025#"))
        #expect(!Validator.isValidPassword("short1#"))          // too short
        #expect(!Validator.isValidPassword("NoNumbers#"))       // no number
        #expect(!Validator.isValidPassword("NoSymbol123"))      // no symbol
    }

    @Test("Password strength goes up as the password gets better")
    func passwordStrength() {
        #expect(Validator.passwordStrength("") == .empty)
        #expect(Validator.passwordStrength("abc") == .weak)
        #expect(Validator.passwordStrength("abcdefgh1").rawValue < Validator.passwordStrength("GrocerySmart2025#").rawValue)
        #expect(Validator.passwordStrength("GrocerySmart2025#") == .strong)
    }

    @Test("Invite codes are exactly 6 letters or numbers")
    func inviteCodes() {
        #expect(Validator.isValidInviteCode("K7Q2MX"))
        #expect(!Validator.isValidInviteCode("K7Q2M"))
        #expect(!Validator.isValidInviteCode("K7Q2MX9"))
        #expect(!Validator.isValidInviteCode("K7-2MX"))
    }

    @Test("Generated invite codes are always valid")
    func generatedInviteCodes() {
        for _ in 0..<50 {
            #expect(Validator.isValidInviteCode(Household.makeInviteCode()))
        }
    }

    @Test("Passcodes: 6 digits, not all the same, not in order")
    func passcodes() {
        #expect(Validator.isValidPasscode("482915"))
        #expect(!Validator.isValidPasscode("111111"))
        #expect(!Validator.isValidPasscode("123456"))
        #expect(!Validator.isValidPasscode("12345"))
        #expect(!Validator.isValidPasscode("12a456"))
    }
}
