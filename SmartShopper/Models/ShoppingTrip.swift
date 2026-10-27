//
//  ShoppingTrip.swift
//  SmartShopper
//
//  A finished shopping trip. Created when the user taps "Finish Shopping Trip".
//  Saved in Firestore at households/{id}/trips/{tripId}.
//

import Foundation

struct TripItem: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var category: ItemCategory
    var price: Double
    var quantity: Int
    /// Who added the item (used for the family cost split).
    var addedByName: String
}

struct ShoppingTrip: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var storeName: String
    var storeArea: String
    var date: Date
    var items: [TripItem]
    /// How many items were on the list when the trip started.
    var plannedCount: Int
    /// Minutes the trip took in the shop.
    var durationMinutes: Int
    /// Minutes saved by shopping along the route instead of a separate trip.
    var minutesSaved: Int
    var familyMemberCount: Int = 1

    /// Sum of all item prices.
    var total: Double {
        items.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    /// 0...1 - picked items divided by planned items.
    var completionRate: Double {
        guard plannedCount > 0 else { return 1 }
        return min(1, Double(items.count) / Double(plannedCount))
    }

    /// "83% (5/6)"
    var completionText: String {
        "\(Int((completionRate * 100).rounded()))% (\(items.count)/\(plannedCount))"
    }
}
