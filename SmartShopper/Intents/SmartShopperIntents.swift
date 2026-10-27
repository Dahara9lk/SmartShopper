//
//  SmartShopperIntents.swift
//  SmartShopper
//
//  App Intents = Siri and Shortcuts support.
//    "Add an item to SmartShopper"     -> asks for the item name, Core ML picks the category
//    "Show my SmartShopper list"       -> opens the Lists tab
//    "Find shops with SmartShopper"    -> opens Smart Map
//
//  Test: run the app once, then open the Shortcuts app - the shortcuts appear under SmartShopper.
//

import AppIntents
import Foundation

struct AddItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Item to Shopping List"
    static var description = IntentDescription("Adds an item to your SmartShopper list. The category is picked on-device by Core ML.")

    @Parameter(title: "Item", requestValueDialog: "What do you want to add?")
    var itemName: String

    @Parameter(title: "Add to Family List", default: false)
    var familyList: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AppEnvironment.shared.store
        if store.authState == .loading {
            await store.start()
        }
        guard store.authState == .signedIn else {
            return .result(dialog: "Please open SmartShopper and sign in first.")
        }
        store.quickAdd(name: itemName, isFamily: familyList)
        let category = ItemClassifierService.shared.predict(itemName)?.category.title ?? "Pantry"
        let listName = familyList ? "family list" : "list"
        return .result(dialog: "Added \(itemName) to your \(listName) under \(category).")
    }
}

struct OpenListIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Shopping List"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.shared.router.open(.lists)
        return .result()
    }
}

struct FindShopsIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Shops for My List"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppEnvironment.shared.router.open(.smartMap)
        return .result()
    }
}

/// Makes the intents show up in Siri / Spotlight / Shortcuts without any setup.
struct SmartShopperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddItemIntent(),
                    phrases: ["Add an item to \(.applicationName)",
                              "Add to my \(.applicationName) list"],
                    shortTitle: "Add Item",
                    systemImageName: "cart.badge.plus")
        AppShortcut(intent: OpenListIntent(),
                    phrases: ["Show my \(.applicationName) list"],
                    shortTitle: "My List",
                    systemImageName: "checklist")
        AppShortcut(intent: FindShopsIntent(),
                    phrases: ["Find shops with \(.applicationName)"],
                    shortTitle: "Find Shops",
                    systemImageName: "map.fill")
    }
}
