//
//  ItemEditorViewModel.swift
//  SmartShopper
//
//  Add / edit an item (Figma S5). While the user types the name, the on-device
//  Core ML model suggests a category. The user can still pick another one by hand.
//

import Foundation

@MainActor
final class ItemEditorViewModel: ObservableObject {

    @Published var name = "" {
        didSet { updatePrediction() }
    }
    @Published var quantity = 1
    @Published var unit: MeasureUnit = .units
    @Published var category: ItemCategory = .pantry
    @Published var priceText = ""
    @Published var storePreference = "Nearby"
    @Published var isFamily = false
    @Published var isUrgent = false
    @Published var note = ""
    /// Latest Core ML suggestion (shown as "Suggested by on-device AI 91%").
    @Published private(set) var prediction: CategoryPrediction?
    /// Once the user taps a category chip we stop overwriting it.
    @Published private(set) var categoryPickedByHand = false

    private let existing: ShoppingItem?
    private let classifier: ItemClassifierService

    var isEditing: Bool { existing != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity > 0 }

    init(item: ShoppingItem? = nil, startInFamily: Bool = false, classifier: ItemClassifierService = .shared) {
        self.existing = item
        self.classifier = classifier
        if let item {
            name = item.name
            quantity = item.quantity
            unit = item.unit
            category = item.category
            priceText = item.price > 0 ? String(format: "%.2f", item.price) : ""
            storePreference = item.storePreference
            isFamily = item.isFamily
            isUrgent = item.isUrgent
            note = item.note
            categoryPickedByHand = true
        } else {
            isFamily = startInFamily
        }
    }

    func increase() { quantity = min(99, quantity + 1) }
    func decrease() { quantity = max(1, quantity - 1) }

    func pickCategory(_ newCategory: ItemCategory) {
        category = newCategory
        categoryPickedByHand = true
    }

    func useQuickPick(_ text: String) {
        name = text
    }

    /// Runs the Core ML model on the current name.
    private func updatePrediction() {
        prediction = classifier.predict(name)
        if let prediction, !categoryPickedByHand {
            category = prediction.category
        }
    }

    /// Builds the item to save.
    func makeItem(ownerId: String, addedBy: String) -> ShoppingItem {
        let price = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? PriceGuide.estimate(for: category)
        var item = existing ?? ShoppingItem(name: "", ownerId: ownerId, addedByName: addedBy)
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity
        item.unit = unit
        item.category = category
        item.categoryConfidence = categoryPickedByHand ? 0 : (prediction?.confidence ?? 0)
        item.price = price
        item.storePreference = storePreference
        item.isFamily = isFamily
        item.isUrgent = isUrgent
        item.note = note
        return item
    }
}
