//
//  TestHelpers.swift
//  SmartShopperTests
//
//  Small factory functions so every test can build items / trips in one line.
//

import Foundation
@testable import SmartShopper

enum TestData {

    static func item(_ name: String,
                     category: ItemCategory = .pantry,
                     price: Double = 1,
                     quantity: Int = 1,
                     purchased: Bool = false,
                     family: Bool = false,
                     owner: String = "user-1",
                     addedBy: String = "Sarah") -> ShoppingItem {
        ShoppingItem(name: name,
                     quantity: quantity,
                     category: category,
                     price: price,
                     isFamily: family,
                     ownerId: owner,
                     addedByName: addedBy,
                     isPurchased: purchased)
    }

    static func store(_ name: String, type: StoreType, distance: Double) -> NearbyStore {
        NearbyStore(id: name,
                    name: name,
                    type: type,
                    coordinate: .init(latitude: 6.9271, longitude: 79.8612),
                    address: "Colombo",
                    phone: nil,
                    distanceMeters: distance,
                    mapItem: nil)
    }

    static func trip(daysAgo: Int, items: [TripItem], planned: Int, saved: Int = 10) -> ShoppingTrip {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return ShoppingTrip(storeName: "Test Store", storeArea: "Area", date: date, items: items,
                            plannedCount: planned, durationMinutes: 15, minutesSaved: saved)
    }

    static func tripItem(_ name: String, _ category: ItemCategory, _ price: Double, by: String = "Sarah") -> TripItem {
        TripItem(name: name, category: category, price: price, quantity: 1, addedByName: by)
    }

    /// A fresh, empty UserDefaults for each test so tests never share data.
    static func freshDefaults() -> UserDefaults {
        let name = "SmartShopperTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
