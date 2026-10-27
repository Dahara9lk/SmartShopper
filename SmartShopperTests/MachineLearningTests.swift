//
//  MachineLearningTests.swift
//  SmartShopperTests
//
//  The on-device Core ML item classifier and the features it reads.
//

import Testing
@testable import SmartShopper

@Suite("Core ML item classifier")
struct MachineLearningTests {

    @Test("Text is split into lowercase words; symbols are separators")
    func words() {
        #expect(TextFeatures.words(in: "USB-C Cable 2m") == ["usb", "c", "cable", "2m"])
        #expect(TextFeatures.words(in: "  Oat   Milk ") == ["oat", "milk"])
        #expect(TextFeatures.words(in: "").isEmpty)
    }

    @Test("Features match the Python training script (words + 3 and 4 letter chunks)")
    func features() {
        let features = TextFeatures.make(from: "milk")
        // "#milk#" -> 3-chunks: #mi mil ilk lk#   4-chunks: #mil milk ilk#
        let expected: Set<String> = ["w:milk", "c:#mi", "c:mil", "c:ilk", "c:lk#", "c:#mil", "c:milk", "c:ilk#"]
        #expect(Set(features.keys) == expected)
        #expect(features.values.allSatisfy { $0 == 1.0 })
    }

    @Test("Empty text gives no features and no prediction")
    func emptyText() {
        #expect(TextFeatures.make(from: "   ").isEmpty)
        #expect(ItemClassifierService.shared.predict("") == nil)
    }

    @Test("The bundled Core ML model loads")
    func modelLoads() {
        #expect(ItemClassifierService.shared.isModelLoaded)
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
        #expect(prediction.confidence > 0.6 && prediction.confidence <= 1)
        #expect(!prediction.isLowConfidence)
    }

    @Test("Confidence: equal scores split evenly, a clear winner is near 100%")
    func confidenceMaths() {
        let even = ItemClassifierService.confidence(of: "a", in: ["a": 0.5, "b": 0.5])
        #expect(abs(even - 0.5) < 0.0001)
        let clear = ItemClassifierService.confidence(of: "a", in: ["a": 0.99, "b": 0.01, "c": 0.01])
        #expect(clear > 0.99)
        #expect(ItemClassifierService.confidence(of: "x", in: [:]) == 0)
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
