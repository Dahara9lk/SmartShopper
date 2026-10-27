//
//  ListsViewModel.swift
//  SmartShopper
//
//  Screen state for the Lists tab (S3 my list, S6 empty, S10 family list)
//  plus the list maths, written as static functions so they can be unit tested.
//

import Foundation
import Combine

@MainActor
final class ListsViewModel: ObservableObject {

    enum Mode: Int {
        case myList = 0
        case family = 1
    }

    @Published var mode: Mode = .myList
    /// nil = "All"
    @Published var selectedCategory: ItemCategory?
    @Published var itemToEdit: ShoppingItem?
    @Published var showAddItem = false
    @Published var showInStoreMode = false

    // Family list "Add item to family list..." row
    @Published var familyDraft = ""
    @Published var assignTo = "You"
    /// Family list unlocked with Face ID this session (when "Protect Family Shared Lists" is on).
    @Published var familyUnlocked = false

    // MARK: - List maths (pure, testable)

    /// Items shown under the selected filter chip.
    nonisolated static func filter(_ items: [ShoppingItem], by category: ItemCategory?) -> [ShoppingItem] {
        guard let category else { return items }
        return items.filter { $0.category == category }
    }

    /// Chip counts like "Groceries (5)". Only categories that have items are returned, in a fixed order.
    nonisolated static func categoryCounts(_ items: [ShoppingItem]) -> [(category: ItemCategory, count: Int)] {
        ItemCategory.allCases.compactMap { category -> (category: ItemCategory, count: Int)? in
            let count = items.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    /// 0...1 purchased / total
    nonisolated static func progress(_ items: [ShoppingItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isPurchased).count) / Double(items.count)
    }

    /// Sum of the estimated prices of everything on the list.
    nonisolated static func estimatedTotal(_ items: [ShoppingItem]) -> Double {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    /// Remaining items sorted by aisle - "Optimized by aisle order".
    nonisolated static func aisleOrdered(_ items: [ShoppingItem]) -> [ShoppingItem] {
        items.filter { !$0.isPurchased }.sorted {
            if $0.category.aisle == $1.category.aisle { return $0.name < $1.name }
            return $0.category.aisle < $1.category.aisle
        }
    }
}
