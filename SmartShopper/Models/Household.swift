//
//  Household.swift
//  SmartShopper
//
//  A family circle ("Jenkins Family"). Everyone in memberIds can read and
//  write the household's items, trips and activity in Firestore.
//

import Foundation

struct FamilyMember: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var role: String = "Member"

    /// First letter for the avatar circle.
    var initial: String { String(name.prefix(1)).uppercased() }
}

struct Household: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    /// 6-character code other people type to join.
    var inviteCode: String
    var members: [FamilyMember]
    /// Plain list of user ids - used by the Firestore security rules.
    var memberIds: [String]

    /// Makes a random invite code like "K7Q2MX" (no 0/O/1/I so it is easy to read).
    static func makeInviteCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var code = ""
        for _ in 0..<6 {
            code.append(letters.randomElement() ?? "A")
        }
        return code
    }
}

struct UserProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var email: String
    var householdId: String

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

/// One line in the "Family Activity" feed ("Mom added Oat Milk").
struct ActivityEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case added
        case checked
        case trip
        case joined
    }

    var id: String = UUID().uuidString
    var actorName: String
    var itemName: String
    var kind: Kind
    var date: Date = Date()

    var text: String {
        switch kind {
        case .added: return "\(actorName) added \(itemName)"
        case .checked: return "\(actorName) checked off \(itemName)"
        case .trip: return "\(actorName) finished a trip at \(itemName)"
        case .joined: return "\(actorName) joined the family circle"
        }
    }
}
