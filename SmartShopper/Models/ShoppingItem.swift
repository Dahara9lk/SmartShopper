//
//  ShoppingItem.swift
//  SmartShopper

import Foundation


enum MeasureUnit: String, Codable, CaseIterable, Identifiable {
    case units
    case liters
    case kg
    case packs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .units: return "Units"
        case .liters: return "Liters"
        case .kg: return "kg"
        case .packs: return "Packs"
        }
    }

    var shortName: String {
        switch self {
        case .units: return "unit"
        case .liters: return "L"
        case .kg: return "kg"
        case .packs: return "pk"
        }
    }
}

struct ShoppingItem: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var quantity: Int = 1
    var unit: MeasureUnit = .units
    var category: ItemCategory = .pantry
// How sure the Core ML model 0 means the user picked it by hand.
    var categoryConfidence: Double = 0
// Estimated price for the running total.
    var price: Double = 0
    var note: String = ""
    var storePreference: String = "Nearby"
// true = shared Family list, false = my own list.
    var isFamily: Bool = false
    var ownerId: String
    var addedByName: String
//Family member this item is for ("You", "Mom"...)
    var assignedTo: String? = nil
    var isUrgent: Bool = false
    var isPurchased: Bool = false
    var purchasedByName: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

// "2 L", "1 unit", "3 pk"
    var quantityText: String {
        if unit == .units {
            return quantity == 1 ? "1 unit" : "\(quantity) units"
        }
        return "\(quantity) \(unit.shortName)"
    }

// "Whole Milk — 2 L"
    var titleWithQuantity: String { "\(name) — \(quantityText)" }

// Price x quantity
    var lineTotal: Double { price * Double(quantity) }
}
