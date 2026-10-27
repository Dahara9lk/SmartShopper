//
//  ItemCategory.swift
//  SmartShopper
//
//  The 8 shop categories. The Core ML model predicts one of these
//  (the raw values MUST match the labels in ItemCategoryClassifier.mlmodel).
//

import SwiftUI

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case produce
    case dairy
    case bakery
    case pantry
    case household
    case electronics
    case pharmacy
    case personalCare

    var id: String { rawValue }

    /// Name shown on badges and filter chips.
    var title: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy"
        case .bakery: return "Bakery"
        case .pantry: return "Pantry"
        case .household: return "Household"
        case .electronics: return "Electronics"
        case .pharmacy: return "Pharmacy"
        case .personalCare: return "Personal Care"
        }
    }

    /// SF Symbol for the category.
    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "birthday.cake.fill"
        case .pantry: return "cabinet.fill"
        case .household: return "bubbles.and.sparkles.fill"
        case .electronics: return "cable.connector"
        case .pharmacy: return "cross.case.fill"
        case .personalCare: return "hands.and.sparkles.fill"
        }
    }

    /// Badge colour. System colours already adapt to dark mode.
    var color: Color {
        switch self {
        case .produce: return .green
        case .dairy: return .blue
        case .bakery: return .orange
        case .pantry: return .brown
        case .household: return .teal
        case .electronics: return .indigo
        case .pharmacy: return .red
        case .personalCare: return .purple
        }
    }

    /// Simple aisle number used to sort items in In-Store Mode.
    var aisle: Int {
        switch self {
        case .produce: return 1
        case .bakery: return 2
        case .dairy: return 3
        case .pantry: return 4
        case .household: return 5
        case .personalCare: return 6
        case .pharmacy: return 7
        case .electronics: return 8
        }
    }

    /// "Aisle 3 • Dairy"
    var aisleText: String { "Aisle \(aisle) • \(title)" }

    /// Which kinds of shop sell this category. Used by the Smart Map matching.
    var storeTypes: [StoreType] {
        switch self {
        case .produce, .dairy, .pantry, .household: return [.supermarket]
        case .bakery: return [.bakery, .supermarket]
        case .electronics: return [.electronics]
        case .pharmacy: return [.pharmacy]
        case .personalCare: return [.pharmacy, .supermarket]
        }
    }
}

/// Kinds of shop we search for with MapKit.
enum StoreType: String, CaseIterable, Identifiable {
    case supermarket
    case bakery
    case electronics
    case pharmacy

    var id: String { rawValue }

    /// Text sent to MKLocalSearch.
    var searchQuery: String {
        switch self {
        case .supermarket: return "supermarket"
        case .bakery: return "bakery"
        case .electronics: return "electronics store"
        case .pharmacy: return "pharmacy"
        }
    }

    var title: String {
        switch self {
        case .supermarket: return "Supermarket"
        case .bakery: return "Bakery"
        case .electronics: return "Electronics"
        case .pharmacy: return "Pharmacy"
        }
    }

    var icon: String {
        switch self {
        case .supermarket: return "cart.fill"
        case .bakery: return "birthday.cake.fill"
        case .electronics: return "desktopcomputer"
        case .pharmacy: return "cross.case.fill"
        }
    }
}
