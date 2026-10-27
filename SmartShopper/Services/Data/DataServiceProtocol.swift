//
//  DataServiceProtocol.swift
//  SmartShopper
//
//  Everything the app saves or loads goes through this protocol.
//  FirebaseDataService = Cloud Firestore (real backend, real-time family sync).
//  LocalDataService    = demo backend saved on the device (no Firebase needed).
//

import Foundation

/// One update coming from the backend. A nil field means "this part did not change".
struct HouseholdSnapshot {
    var household: Household? = nil
    var items: [ShoppingItem]? = nil
    var trips: [ShoppingTrip]? = nil
    var activity: [ActivityEvent]? = nil
    /// How many items are saved on the phone but not yet uploaded (offline).
    var pendingWrites: Int? = nil
    /// true when Firestore answered from its offline cache.
    var isFromCache: Bool? = nil
}

enum DataError: LocalizedError {
    case householdNotFound
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .householdNotFound: return "No family circle was found with that invite code."
        case .notSignedIn: return "Please sign in again."
        }
    }
}

protocol DataServiceProtocol: AnyObject {
    // Profile
    func loadProfile(userId: String) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws

    // Household (family circle)
    func createHousehold(name: String, owner: FamilyMember) async throws -> Household
    func joinHousehold(inviteCode: String, member: FamilyMember) async throws -> Household

    // Live updates - onChange is called every time something changes.
    func startListening(householdId: String, onChange: @escaping (HouseholdSnapshot) -> Void)
    func stopListening()

    // Items, trips and activity
    func saveItem(_ item: ShoppingItem, householdId: String) async throws
    func deleteItem(id: String, householdId: String) async throws
    func saveTrip(_ trip: ShoppingTrip, householdId: String) async throws
    func addActivity(_ event: ActivityEvent, householdId: String) async throws
}
