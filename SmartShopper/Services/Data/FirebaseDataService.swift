//
//  FirebaseDataService.swift
//  SmartShopper

//  Cloud Firestore backend.


import Foundation
import FirebaseFirestore

final class FirebaseDataService: DataServiceProtocol {

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    private func householdRef(_ id: String) -> DocumentReference {
        db.collection("households").document(id)
    }

// MARK: Profile

    func loadProfile(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserProfile.self)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.id).setData(from: profile)
    }

// MARK: Household

    func createHousehold(name: String, owner: FamilyMember) async throws -> Household {
        let ref = db.collection("households").document()
        var organiser = owner
        organiser.role = "Organizer"
        let household = Household(id: ref.documentID,
                                  name: name,
                                  inviteCode: Household.makeInviteCode(),
                                  members: [organiser],
                                  memberIds: [owner.id])
        try ref.setData(from: household)
        return household
    }

    func joinHousehold(inviteCode: String, member: FamilyMember) async throws -> Household {
        let query = db.collection("households")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .limit(to: 1)
        let result = try await query.getDocuments()
        guard let document = result.documents.first else {
            throw DataError.householdNotFound
        }
        var household = try document.data(as: Household.self)
        if !household.memberIds.contains(member.id) {
            household.members.append(member)
            household.memberIds.append(member.id)
            try document.reference.setData(from: household)
        }
        return household
    }

// MARK: Live listeners

    func startListening(householdId: String, onChange: @escaping (HouseholdSnapshot) -> Void) {
        stopListening()
        let ref = householdRef(householdId)

        // 1. Household document (members list)
        let householdListener = ref.addSnapshotListener { snapshot, _ in
            guard let snapshot, let household = try? snapshot.data(as: Household.self) else { return }
            onChange(HouseholdSnapshot(household: household))
        }

        // 2. Items - includeMetadataChanges
        
        let itemsListener = ref.collection("items")
            .addSnapshotListener(includeMetadataChanges: true) { snapshot, _ in
                guard let snapshot else { return }
                let items = snapshot.documents.compactMap { try? $0.data(as: ShoppingItem.self) }
                let pending = snapshot.documents.filter { $0.metadata.hasPendingWrites }.count
                onChange(HouseholdSnapshot(items: items,
                                           pendingWrites: pending,
                                           isFromCache: snapshot.metadata.isFromCache))
            }

        // 3. Trips (newest first)
        let tripsListener = ref.collection("trips")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let trips = snapshot.documents.compactMap { try? $0.data(as: ShoppingTrip.self) }
                onChange(HouseholdSnapshot(trips: trips))
            }

        // 4. Activity feed (latest 20)
        let activityListener = ref.collection("activity")
            .order(by: "date", descending: true)
            .limit(to: 20)
            .addSnapshotListener { snapshot, _ in
                guard let snapshot else { return }
                let events = snapshot.documents.compactMap { try? $0.data(as: ActivityEvent.self) }
                onChange(HouseholdSnapshot(activity: events))
            }

        listeners = [householdListener, itemsListener, tripsListener, activityListener]
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: Writes
    // setData(from:) queues the write in the offline cache straight away,
    // so these work even with no internet.

    func saveItem(_ item: ShoppingItem, householdId: String) async throws {
        try householdRef(householdId).collection("items").document(item.id).setData(from: item)
    }

    func deleteItem(id: String, householdId: String) async throws {
        // completion: nil picks the non-waiting version, so it also works offline.
        householdRef(householdId).collection("items").document(id).delete(completion: nil)
    }

    func saveTrip(_ trip: ShoppingTrip, householdId: String) async throws {
        try householdRef(householdId).collection("trips").document(trip.id).setData(from: trip)
    }

    func addActivity(_ event: ActivityEvent, householdId: String) async throws {
        try householdRef(householdId).collection("activity").document(event.id).setData(from: event)
    }
}
