//
//  AppDataStore.swift
//  SmartShopper
//
//  The app's shared data (signed-in user, family circle, items, trips, activity).
//  Views read it with @EnvironmentObject; changes are sent to the backend
//  (Firestore or demo) and the live listener sends the result back here.
//

import Foundation
import SwiftUI
import Combine


@MainActor
final class AppDataStore: ObservableObject {

    enum AuthState: Equatable {
        case loading
        case signedOut
        case signedIn
    }

    // MARK: Published data
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var profile: UserProfile?
    @Published private(set) var household: Household?
    @Published private(set) var items: [ShoppingItem] = []
    @Published private(set) var trips: [ShoppingTrip] = []
    @Published private(set) var activity: [ActivityEvent] = []
    @Published private(set) var pendingSyncCount = 0
    @Published private(set) var isShowingCachedData = false
    @Published var errorMessage: String?

    // MARK: Services
    let auth: AuthServiceProtocol
    let data: DataServiceProtocol
    /// true when running without Firebase (no GoogleService-Info.plist).
    let isDemoMode: Bool
    private let settings: SettingsStore
    /// Skips family alerts for the very first load.
    private var hasLoadedItemsOnce = false

    init(auth: AuthServiceProtocol, data: DataServiceProtocol, settings: SettingsStore, isDemoMode: Bool) {
        self.auth = auth
        self.data = data
        self.settings = settings
        self.isDemoMode = isDemoMode
    }

    // MARK: - Derived lists

    var myItems: [ShoppingItem] {
        items.filter { !$0.isFamily && $0.ownerId == profile?.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var familyItems: [ShoppingItem] {
        items.filter { $0.isFamily }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Everything still to buy (my list + family list) - used for Smart Map matching.
    var allRemainingItems: [ShoppingItem] {
        (myItems + familyItems).filter { !$0.isPurchased }
    }

    var members: [FamilyMember] { household?.members ?? [] }

    var userName: String { profile?.name ?? "You" }

    // MARK: - Session

    /// Called when the app starts: if Firebase remembers the user, load their data.
    func start() async {
        guard let uid = auth.currentUserId else {
            authState = .signedOut
            return
        }
        await loadUser(uid: uid)
    }

    private func loadUser(uid: String) async {
        do {
            if let saved = try await data.loadProfile(userId: uid) {
                profile = saved
                listen(to: saved.householdId)
                authState = .signedIn
            } else {
                // Account exists but no profile (sign-up was interrupted) - sign out to start again.
                try? auth.signOut()
                authState = .signedOut
            }
        } catch {
            errorMessage = error.localizedDescription
            authState = .signedOut
        }
    }

    /// Sign in with email + password.
    func signIn(email: String, password: String) async throws {
        let uid = try await auth.signIn(email: email, password: password)
        await loadUser(uid: uid)
    }

    /// Creates the account, the profile and the family circle (new or joined with a code).
    func createAccount(name: String, email: String, password: String,
                       householdName: String, inviteCode: String?) async throws {
        let uid = try await auth.signUp(email: email, password: password)
        let me = FamilyMember(id: uid, name: name)
        let circle: Household
        if let inviteCode, !inviteCode.isEmpty {
            circle = try await data.joinHousehold(inviteCode: inviteCode, member: me)
            try await data.addActivity(ActivityEvent(actorName: name, itemName: "", kind: .joined),
                                       householdId: circle.id)
        } else {
            circle = try await data.createHousehold(name: householdName, owner: me)
        }
        let newProfile = UserProfile(id: uid, name: name, email: email.lowercased(), householdId: circle.id)
        try await data.saveProfile(newProfile)
        profile = newProfile
        household = circle
        listen(to: circle.id)
        authState = .signedIn
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(email: email)
    }

    func signOut() {
        data.stopListening()
        try? auth.signOut()
        profile = nil
        household = nil
        items = []
        trips = []
        activity = []
        hasLoadedItemsOnce = false
        authState = .signedOut
    }

    // MARK: - Live updates

    private func listen(to householdId: String) {
        data.startListening(householdId: householdId) { [weak self] snapshot in
            // The backend may call us from any thread - hop to the main actor.
            Task { @MainActor in
                self?.apply(snapshot)
            }
        }
    }

    private func apply(_ snapshot: HouseholdSnapshot) {
        if let household = snapshot.household { self.household = household }
        if let trips = snapshot.trips { self.trips = trips }
        if let activity = snapshot.activity { self.activity = activity }
        if let pending = snapshot.pendingWrites { pendingSyncCount = pending }
        if let cached = snapshot.isFromCache { isShowingCachedData = cached }
        if let newItems = snapshot.items {
            if hasLoadedItemsOnce {
                notifyFamilyChanges(old: items, new: newItems)
            }
            items = newItems
            hasLoadedItemsOnce = true
        }
    }

    /// Sends "Mom added Oat Milk" / "Dad checked off Olive Oil" notifications
    /// for changes made by OTHER family members.
    private func notifyFamilyChanges(old: [ShoppingItem], new: [ShoppingItem]) {
        let oldById = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in new where item.isFamily {
            if let before = oldById[item.id] {
                if !before.isPurchased, item.isPurchased,
                   let who = item.purchasedByName, who != userName,
                   settings.familyCheckedAlerts, settings.shouldDeliver(isUrgent: false) {
                    NotificationService.shared.sendFamilyAlert(title: "Family list updated",
                                                               body: "\(who) checked off \(item.name)")
                }
            } else if item.addedByName != userName,
                      settings.familyItemAlerts,
                      settings.shouldDeliver(isUrgent: item.isUrgent) {
                NotificationService.shared.sendFamilyAlert(title: "New family item",
                                                           body: "\(item.addedByName) added \(item.name)")
            }
        }
    }

    // MARK: - Items

    /// Adds or updates an item (shows straight away, then syncs).
    func save(_ item: ShoppingItem) {
        guard let householdId = profile?.householdId else { return }
        var updated = item
        updated.updatedAt = Date()
        let isNew = !items.contains { $0.id == item.id }
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updated
        } else {
            items.append(updated)
        }
        Task {
            do {
                try await data.saveItem(updated, householdId: householdId)
                if isNew && updated.isFamily {
                    try await data.addActivity(ActivityEvent(actorName: userName, itemName: updated.name, kind: .added),
                                               householdId: householdId)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Quick add from a name only (Family list field, staples grid, Siri).
    func quickAdd(name: String, isFamily: Bool, assignedTo: String? = nil, isUrgent: Bool = false) {
        guard let profile else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let prediction = ItemClassifierService.shared.predict(cleanName)
        let item = ShoppingItem(name: cleanName.capitalized,
                                category: prediction?.category ?? .pantry,
                                categoryConfidence: prediction?.confidence ?? 0,
                                price: PriceGuide.estimate(for: prediction?.category ?? .pantry),
                                isFamily: isFamily,
                                ownerId: profile.id,
                                addedByName: profile.name,
                                assignedTo: assignedTo,
                                isUrgent: isUrgent)
        save(item)
    }

    func togglePurchased(_ item: ShoppingItem) {
        var changed = item
        changed.isPurchased.toggle()
        changed.purchasedByName = changed.isPurchased ? userName : nil
        save(changed)
        if changed.isPurchased && changed.isFamily, let householdId = profile?.householdId {
            Task {
                try? await data.addActivity(ActivityEvent(actorName: userName, itemName: item.name, kind: .checked),
                                            householdId: householdId)
            }
        }
    }

    func delete(_ item: ShoppingItem) {
        guard let householdId = profile?.householdId else { return }
        items.removeAll { $0.id == item.id }
        Task {
            try? await data.deleteItem(id: item.id, householdId: householdId)
        }
    }

    /// "Clear Completed" - removes purchased items from one list.
    func clearCompleted(family: Bool) {
        let done = (family ? familyItems : myItems).filter { $0.isPurchased }
        done.forEach { delete($0) }
    }

    /// "Restore from Recent Trip" - adds the items from the last trip back to my list.
    func restoreFromLastTrip() {
        guard let profile, let lastTrip = trips.first else { return }
        for tripItem in lastTrip.items {
            let item = ShoppingItem(name: tripItem.name,
                                    quantity: tripItem.quantity,
                                    category: tripItem.category,
                                    price: tripItem.price,
                                    ownerId: profile.id,
                                    addedByName: profile.name)
            save(item)
        }
    }

    // MARK: - Trips

    /// Called by In-Store Mode when the user taps "Finish Shopping Trip".
    /// Marks the picked items as purchased and saves the trip to History.
    @discardableResult
    func finishTrip(storeName: String, storeArea: String, picked: [ShoppingItem],
                    plannedCount: Int, durationMinutes: Int, minutesSaved: Int) -> ShoppingTrip {
        let trip = ShoppingTrip(storeName: storeName,
                                storeArea: storeArea,
                                date: Date(),
                                items: picked.map {
                                    TripItem(name: $0.name, category: $0.category, price: $0.price,
                                             quantity: $0.quantity, addedByName: $0.addedByName)
                                },
                                plannedCount: plannedCount,
                                durationMinutes: durationMinutes,
                                minutesSaved: minutesSaved,
                                familyMemberCount: max(1, members.count))
        for item in picked where !item.isPurchased {
            var bought = item
            bought.isPurchased = true
            bought.purchasedByName = userName
            save(bought)
        }
        trips.insert(trip, at: 0)
        if let householdId = profile?.householdId {
            Task {
                try? await data.saveTrip(trip, householdId: householdId)
                try? await data.addActivity(ActivityEvent(actorName: userName, itemName: storeName, kind: .trip),
                                            householdId: householdId)
            }
        }
        if settings.tripSummaryAlerts {
            NotificationService.shared.sendFamilyAlert(title: "Trip completed",
                                                       body: "\(userName) spent \(AppFormat.money(trip.total)) at \(storeName)")
        }
        return trip
    }

    /// "Log Past Receipt Manually" on the empty History screen.
    func logManualTrip(storeName: String, total: Double, itemCount: Int, date: Date) {
        let count = max(1, itemCount)
        let each = total / Double(count)
        let tripItems = (1...count).map {
            TripItem(name: "Item \($0)", category: .pantry, price: each, quantity: 1, addedByName: userName)
        }
        let trip = ShoppingTrip(storeName: storeName, storeArea: "Logged manually", date: date,
                                items: tripItems, plannedCount: count, durationMinutes: 0, minutesSaved: 0)
        trips.insert(trip, at: 0)
        trips.sort { $0.date > $1.date }
        if let householdId = profile?.householdId {
            Task { try? await data.saveTrip(trip, householdId: householdId) }
        }
    }

    /// "Load Demo History Data" - adds 4 sample trips so the charts have something to show.
    func loadDemoHistory() {
        guard let householdId = profile?.householdId else { return }
        for trip in DemoData.sampleTrips(userName: userName) {
            trips.append(trip)
            Task { try? await data.saveTrip(trip, householdId: householdId) }
        }
        trips.sort { $0.date > $1.date }
    }
}

/// Very rough price guide so the running total has realistic numbers
/// before the user types real prices.
enum PriceGuide {
    static func estimate(for category: ItemCategory) -> Double {
        switch category {
        case .produce: return 2.99
        case .dairy: return 3.49
        case .bakery: return 4.20
        case .pantry: return 4.50
        case .household: return 5.25
        case .electronics: return 12.99
        case .pharmacy: return 6.50
        case .personalCare: return 5.99
        }
    }
}
