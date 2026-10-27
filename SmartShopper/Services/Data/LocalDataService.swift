//
//  LocalDataService.swift
//  SmartShopper
//
//  DEMO MODE backend. Works exactly like FirebaseDataService but keeps everything
//  in a JSON blob in UserDefaults on this device. Used when Firebase is not
//  configured yet, and by the unit tests (with a separate UserDefaults suite).
//

import Foundation

final class LocalDataService: DataServiceProtocol {

    /// Everything we store, saved as one JSON blob.
    private struct Database: Codable {
        var profiles: [String: UserProfile] = [:]
        var households: [String: Household] = [:]
        var items: [String: [ShoppingItem]] = [:]       // householdId -> items
        var trips: [String: [ShoppingTrip]] = [:]
        var activity: [String: [ActivityEvent]] = [:]
    }

    private let defaults: UserDefaults
    private let key = "demo.database"
    private var database: Database
    private var listeningId: String?
    private var onChange: ((HouseholdSnapshot) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(Database.self, from: data) {
            database = saved
        } else {
            database = Database()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(database) {
            defaults.set(data, forKey: key)
        }
    }

    /// Sends the latest data to whoever is listening.
    private func notify() {
        guard let id = listeningId, let onChange else { return }
        onChange(HouseholdSnapshot(household: database.households[id],
                                   items: database.items[id] ?? [],
                                   trips: (database.trips[id] ?? []).sorted { $0.date > $1.date },
                                   activity: Array((database.activity[id] ?? []).sorted { $0.date > $1.date }.prefix(20)),
                                   pendingWrites: 0,
                                   isFromCache: false))
    }

    // MARK: Profile

    func loadProfile(userId: String) async throws -> UserProfile? {
        database.profiles[userId]
    }

    func saveProfile(_ profile: UserProfile) async throws {
        database.profiles[profile.id] = profile
        persist()
    }

    // MARK: Household

    func createHousehold(name: String, owner: FamilyMember) async throws -> Household {
        var organiser = owner
        organiser.role = "Organizer"
        let household = Household(id: UUID().uuidString,
                                  name: name,
                                  inviteCode: Household.makeInviteCode(),
                                  members: [organiser],
                                  memberIds: [owner.id])
        database.households[household.id] = household
        persist()
        return household
    }

    func joinHousehold(inviteCode: String, member: FamilyMember) async throws -> Household {
        guard var household = database.households.values.first(where: { $0.inviteCode == inviteCode.uppercased() }) else {
            throw DataError.householdNotFound
        }
        if !household.memberIds.contains(member.id) {
            household.members.append(member)
            household.memberIds.append(member.id)
            database.households[household.id] = household
            persist()
        }
        return household
    }

    // MARK: Listening

    func startListening(householdId: String, onChange: @escaping (HouseholdSnapshot) -> Void) {
        listeningId = householdId
        self.onChange = onChange
        notify()
    }

    func stopListening() {
        listeningId = nil
        onChange = nil
    }

    // MARK: Writes

    func saveItem(_ item: ShoppingItem, householdId: String) async throws {
        var list = database.items[householdId] ?? []
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            list[index] = item
        } else {
            list.append(item)
        }
        database.items[householdId] = list
        persist()
        notify()
    }

    func deleteItem(id: String, householdId: String) async throws {
        database.items[householdId]?.removeAll { $0.id == id }
        persist()
        notify()
    }

    func saveTrip(_ trip: ShoppingTrip, householdId: String) async throws {
        var list = database.trips[householdId] ?? []
        list.removeAll { $0.id == trip.id }
        list.append(trip)
        database.trips[householdId] = list
        persist()
        notify()
    }

    func addActivity(_ event: ActivityEvent, householdId: String) async throws {
        var list = database.activity[householdId] ?? []
        list.append(event)
        database.activity[householdId] = list
        persist()
        notify()
    }
}
