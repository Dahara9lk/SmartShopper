//
//  DataStoreTests.swift
//  SmartShopperTests
//
//  AppDataStore + the demo backend (LocalAuthService / LocalDataService).
//  Each test gets its own empty UserDefaults, so nothing leaks between tests
//  and no Firebase project is needed to run them.
//

import Foundation
import Testing
@testable import SmartShopper

@Suite("Accounts and shared data")
@MainActor
struct DataStoreTests {

    private func makeStore(defaults: UserDefaults? = nil) -> AppDataStore {
        let defaults = defaults ?? TestData.freshDefaults()
        return AppDataStore(auth: LocalAuthService(defaults: defaults),
                            data: LocalDataService(defaults: defaults),
                            settings: SettingsStore(defaults: defaults),
                            isDemoMode: true)
    }

    @Test("Creating an account signs in and creates a family circle")
    func createAccount() async throws {
        let store = makeStore()
        try await store.createAccount(name: "Sarah Jenkins", email: "sarah@icloud.com",
                                      password: "GrocerySmart2025#", householdName: "Jenkins Family", inviteCode: nil)
        #expect(store.authState == .signedIn)
        #expect(store.profile?.firstName == "Sarah")
        #expect(store.household?.name == "Jenkins Family")
        #expect(store.members.first?.role == "Organizer")
    }

    @Test("Signing up twice with the same email fails")
    func duplicateEmail() async throws {
        let defaults = TestData.freshDefaults()
        let auth = LocalAuthService(defaults: defaults)
        _ = try await auth.signUp(email: "sarah@icloud.com", password: "GrocerySmart2025#")
        await #expect(throws: AuthError.self) {
            _ = try await auth.signUp(email: "sarah@icloud.com", password: "GrocerySmart2025#")
        }
    }

    @Test("Wrong password is rejected")
    func wrongPassword() async throws {
        let auth = LocalAuthService(defaults: TestData.freshDefaults())
        _ = try await auth.signUp(email: "sarah@icloud.com", password: "GrocerySmart2025#")
        await #expect(throws: AuthError.self) {
            _ = try await auth.signIn(email: "sarah@icloud.com", password: "wrong-password1!")
        }
    }

    @Test("A second person can join with the invite code")
    func joinWithInviteCode() async throws {
        let defaults = TestData.freshDefaults()
        let first = makeStore(defaults: defaults)
        try await first.createAccount(name: "Sarah", email: "sarah@icloud.com", password: "GrocerySmart2025#",
                                      householdName: "Jenkins Family", inviteCode: nil)
        let code = try #require(first.household?.inviteCode)
        first.signOut()

        let second = makeStore(defaults: defaults)
        try await second.createAccount(name: "Alex", email: "alex@icloud.com", password: "GrocerySmart2025#",
                                       householdName: "", inviteCode: code)
        #expect(second.household?.name == "Jenkins Family")
        #expect(second.household?.memberIds.count == 2)
    }

    @Test("A wrong invite code gives a clear error")
    func badInviteCode() async {
        let store = makeStore()
        await #expect(throws: DataError.self) {
            try await store.createAccount(name: "Alex", email: "alex@icloud.com", password: "GrocerySmart2025#",
                                          householdName: "", inviteCode: "ZZZZZZ")
        }
    }

    @Test("Quick add uses Core ML for the category and shows the item straight away")
    func quickAdd() async throws {
        let store = makeStore()
        try await store.createAccount(name: "Sarah", email: "sarah@icloud.com", password: "GrocerySmart2025#",
                                      householdName: "Home", inviteCode: nil)
        store.quickAdd(name: "whole milk", isFamily: false)
        store.quickAdd(name: "usb-c cable", isFamily: true)
        #expect(store.myItems.map(\.name) == ["Whole Milk"])
        #expect(store.myItems.first?.category == .dairy)
        #expect(store.familyItems.first?.category == .electronics)
        #expect(store.allRemainingItems.count == 2)
    }

    @Test("Toggle, finish trip and clear completed")
    func tripFlow() async throws {
        let store = makeStore()
        try await store.createAccount(name: "Sarah", email: "sarah@icloud.com", password: "GrocerySmart2025#",
                                      householdName: "Home", inviteCode: nil)
        store.quickAdd(name: "bread", isFamily: false)
        store.quickAdd(name: "bananas", isFamily: false)
        let bread = try #require(store.myItems.first { $0.name == "Bread" })

        let trip = store.finishTrip(storeName: "GreenValley", storeArea: "Colombo", picked: [bread],
                                    plannedCount: 2, durationMinutes: 12, minutesSaved: 8)
        #expect(trip.items.count == 1)
        #expect(trip.completionRate == 0.5)
        #expect(store.trips.first?.storeName == "GreenValley")
        #expect(store.myItems.first { $0.name == "Bread" }?.isPurchased == true)

        store.clearCompleted(family: false)
        #expect(store.myItems.map(\.name) == ["Bananas"])
    }

    @Test("Signing out clears the user's data from memory")
    func signOut() async throws {
        let store = makeStore()
        try await store.createAccount(name: "Sarah", email: "sarah@icloud.com", password: "GrocerySmart2025#",
                                      householdName: "Home", inviteCode: nil)
        store.quickAdd(name: "milk", isFamily: false)
        store.signOut()
        #expect(store.authState == .signedOut)
        #expect(store.items.isEmpty)
        #expect(store.profile == nil)
    }
}

@Suite("Settings")
struct SettingsTests {

    @Test("Defaults on first run")
    func defaults() {
        let settings = SettingsStore(defaults: TestData.freshDefaults())
        #expect(settings.appearance == .system)
        #expect(settings.colorScheme == nil)
        #expect(settings.alertRadiusMeters == 500)
        #expect(settings.quietStartHour == 22)
        #expect(settings.faceIDEnabled == false)
    }

    @Test("Changes are saved and loaded again")
    func persistence() {
        let defaults = TestData.freshDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.appearance = .dark
        settings.alertRadiusMeters = 1000
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.colorScheme == .dark)
        #expect(reloaded.alertRadiusMeters == 1000)
    }

    @Test("Lock timeout titles")
    func lockTitles() {
        #expect(SettingsStore.lockTimeoutTitle(0) == "Immediately")
        #expect(SettingsStore.lockTimeoutTitle(60) == "After 1 minute")
        #expect(SettingsStore.lockTimeoutTitle(300) == "After 5 minutes")
    }

    @Test("Greeting changes with the time of day")
    func greeting() {
        #expect(HomeHelper.greeting(hour: 8) == "Good morning")
        #expect(HomeHelper.greeting(hour: 14) == "Good afternoon")
        #expect(HomeHelper.greeting(hour: 21) == "Good evening")
    }
}
