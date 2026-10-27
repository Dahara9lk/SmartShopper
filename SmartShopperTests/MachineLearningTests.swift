//
//  MachineLearningTests.swift
//  SmartShopperTests
//
//  The on-device item classifier (Core ML model, with the keyword backup).
//

import Testing
@testable import SmartShopper

@Suite("Item classifier")
struct MachineLearningTests {

    @Test("Empty text gives no prediction")
    func emptyText() {
        #expect(ItemClassifierService.shared.predict("") == nil)
        #expect(ItemClassifierService.shared.predict("   ") == nil)
    }

    @Test("Common items are classified into the right shop category", arguments: [
        ("Whole Milk", ItemCategory.dairy),
        ("Sourdough Bread", .bakery),
        ("USB-C Cable", .electronics),
        ("Herbal Shampoo", .personalCare),
        ("Panadol", .pharmacy),
        ("Dish Soap", .household),
        ("Bananas", .produce),
        ("Basmati Rice", .pantry)
    ])
    func classifies(name: String, expected: ItemCategory) throws {
        let prediction = try #require(ItemClassifierService.shared.predict(name))
        #expect(prediction.category == expected)
        #expect(prediction.confidence > 0 && prediction.confidence <= 1)
    }

    @Test("Keyword backup: multi-word keywords win over single words")
    func keywordBackup() {
        #expect(KeywordClassifier.predict("dish soap").category == .household)
        #expect(KeywordClassifier.predict("hand cream").category == .personalCare)
        #expect(KeywordClassifier.predict("toilet paper").category == .household)
    }

    @Test("Keyword backup: unknown words get a low confidence")
    func unknownWord() {
        let prediction = KeywordClassifier.predict("gizmo")
        #expect(prediction.isLowConfidence)
        #expect(prediction.category == .pantry)
    }

    @Test("Confidence text is a rounded percentage")
    func confidenceText() {
        #expect(CategoryPrediction(category: .dairy, confidence: 0.914).confidenceText == "91%")
    }

    @Test("Each category maps to at least one kind of shop")
    func categoryToShop() {
        for category in ItemCategory.allCases {
            #expect(!category.storeTypes.isEmpty)
        }
        #expect(ItemCategory.electronics.storeTypes == [.electronics])
        #expect(ItemCategory.bakery.storeTypes.contains(.supermarket))
    }
}
