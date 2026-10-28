//
//  AppRouter.swift
//  SmartShopper
//
//  Which tab is selected. Shared so Home's quick actions, notifications and
//  Siri shortcuts can switch tabs.


import Foundation


@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    // Lists tab opens on the Family list when this is true.
    @Published var openFamilyList = false
    // Home "Add Item" quick action.
    @Published var showAddItemSheet = false
    // Bell in the header.
    @Published var showActivitySheet = false

    func open(_ tab: AppTab) {
        selectedTab = tab
    }
}

// Small helpers for the Home dashboard (Figma S11).
enum HomeHelper {

    // "Good morning" / "Good afternoon" / "Good evening"
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // Tip card text based on the list and the best shop.
    static func tip(items: [ShoppingItem], topStore: NearbyStore?) -> String {
        let remaining = items.filter { !$0.isPurchased }
        if remaining.isEmpty {
            return "Your list is empty. Add a few staples so SmartShopper can match them to shops on your way."
        }
        if let topStore {
            return "\(topStore.name) has \(topStore.matchedItems.count) of your \(remaining.count) items and is \(AppFormat.distance(topStore.distanceMeters)) away."
        }
        let urgent = remaining.filter(\.isUrgent)
        if let first = urgent.first {
            return "\(first.name) is marked urgent. Open Smart Map to find the nearest shop that has it."
        }
        return "Open Smart Map to find shops that have your \(remaining.count) remaining items."
    }
}
