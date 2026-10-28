//
//  WidgetShared.swift
//  SmartShopper
//



import Foundation
/// What the widget shows.
struct WidgetSnapshot: Codable, Equatable {
    var itemsLeft: Int
    var nextItems: [String]          // first few items still to buy
    var familyItemsLeft: Int
    var totalText: String            // "US$12.50"
    var bestShopName: String?        // best match from Smart Map
    var bestShopMatches: Int
    var updatedAt: Date

    static let empty = WidgetSnapshot(itemsLeft: 0, nextItems: [], familyItemsLeft: 0,
                                      totalText: "", bestShopName: nil, bestShopMatches: 0,
                                      updatedAt: Date())

    /// Shown in the widget gallery before the app has saved real data.
    static let sample = WidgetSnapshot(itemsLeft: 4, nextItems: ["Almond Milk", "Organic Eggs", "Bread"],
                                       familyItemsLeft: 2, totalText: "US$18.40",
                                       bestShopName: "SPAR Supermarket", bestShopMatches: 3,
                                       updatedAt: Date())
}

/// Reads and writes the snapshot in the shared App Group.
enum WidgetStorage {
    /// Must be EXACTLY the same App Group in Signing & Capabilities of both targets.
    static let appGroup = "group.lk.nibm.smartshopper"
    private static let key = "widgetSnapshot"
    
    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
    
    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

