//
//  ItemClassifierService.swift
//  SmartShopper
//
//  ON-DEVICE MACHINE LEARNING (Core ML + Natural Language).
//
//  ItemCategoryClassifier.mlmodel is a Text Classifier trained with Apple's Create ML app
//  on MLTraining/items_dataset.csv (item name -> shop category). Steps are in the README.
//
//  HYBRID: well-known words ("milk", "panadol") are matched with simple keyword rules,
//  and anything else ("gotukola", "airpods") is predicted by the Core ML model.
//  If the model file is missing, the keyword matcher alone is used, so the app still works.
//

import Foundation
import CoreML
import NaturalLanguage

/// Result of one prediction.
struct CategoryPrediction: Equatable {
    let category: ItemCategory
    /// 0...1 - how sure we are.
    let confidence: Double

    /// "91%"
    var confidenceText: String { "\(Int((confidence * 100).rounded()))%" }

    /// Below this we tell the user to double-check the category.
    var isLowConfidence: Bool { confidence < 0.45 }
}

final class ItemClassifierService {

    static let shared = ItemClassifierService()

    /// The Create ML text classifier. nil if it has not been added yet.
    private let model: NLModel?

    init() {
        // Xcode turns ItemCategoryClassifier.mlmodel into ItemCategoryClassifier.mlmodelc
        if let url = Bundle.main.url(forResource: "ItemCategoryClassifier", withExtension: "mlmodelc"),
           let mlModel = try? MLModel(contentsOf: url),
           let nlModel = try? NLModel(mlModel: mlModel) {
            model = nlModel
        } else {
            model = nil
        }
    }

    /// true when the Core ML model is in the app (shown in Profile).
    var isModelLoaded: Bool { model != nil }

    /// Predicts the shop category for an item name. Returns nil for empty text.
    func predict(_ itemName: String) -> CategoryPrediction? {
        let text = itemName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        // Hybrid approach:
        // 1. Item contains a word we know for sure ("milk", "panadol") -> use the keyword rule.
        let keywordGuess = KeywordClassifier.predict(text)
        if !keywordGuess.isLowConfidence {
            return keywordGuess
        }

        // 2. Unknown words ("gotukola", "airpods") -> ask the Core ML model.
        if let model {
            // Scores for every category, e.g. ["dairy": 0.71, "pantry": 0.12, ...]
            let scores = model.predictedLabelHypotheses(for: text, maximumCount: ItemCategory.allCases.count)
            if let best = scores.max(by: { $0.value < $1.value }),
               let category = ItemCategory(rawValue: best.key) {
                return CategoryPrediction(category: category, confidence: best.value)
            }
        }

        // 3. No model: best keyword guess (low confidence, so the UI asks the user to check it)
        return keywordGuess
    }
}

/// Simple backup classifier: looks for known words in the item name.
enum KeywordClassifier {

    static let keywords: [ItemCategory: [String]] = [
        .produce: ["apple", "banana", "mango", "papaya", "pineapple", "grape", "berry", "orange",
                   "lemon", "lime", "avocado", "tomato", "potato", "onion", "garlic", "ginger", "carrot",
                   "cabbage", "lettuce", "spinach", "kale", "broccoli", "cucumber", "pepper", "pumpkin",
                   "leek", "bean", "okra", "brinjal", "eggplant", "mushroom", "coconut", "fruit",
                   "vegetable", "salad", "corn"],
        .dairy: ["milk", "cheese", "butter", "yogurt", "yoghurt", "curd", "cream", "egg", "ghee", "paneer"],
        .bakery: ["bread", "loaf", "sourdough", "bun", "cake", "croissant", "bagel", "muffin", "baguette",
                  "roll", "pastry", "donut", "cookie", "pie", "brioche", "naan", "tortilla"],
        .pantry: ["rice", "pasta", "spaghetti", "noodle", "flour", "sugar", "salt", "oil", "sauce", "ketchup",
                  "tea", "coffee", "cereal", "oat", "lentil", "dhal", "spice", "powder", "honey", "jam",
                  "juice", "water", "chips", "biscuit", "chocolate", "nut", "chicken", "fish", "tuna"],
        .household: ["dish soap", "dish", "detergent", "bleach", "cleaner", "tissue", "towel", "toilet paper",
                     "foil", "garbage", "trash", "sponge", "mop", "broom", "battery", "batteries",
                     "bulb", "candle", "soap"],
        .electronics: ["usb", "cable", "charger", "adapter", "headphone", "earphone", "earbud", "speaker",
                       "hdmi", "mouse", "keyboard", "power bank", "sd card", "router", "monitor"],
        .pharmacy: ["panadol", "paracetamol", "ibuprofen", "aspirin", "tablet", "medicine", "syrup", "vitamin",
                    "plaster", "bandage", "antiseptic", "thermometer", "drops", "capsule", "pill", "sanitizer"],
        .personalCare: ["shampoo", "conditioner", "toothpaste", "toothbrush", "deodorant", "lotion", "razor",
                        "shaving", "sunscreen", "perfume", "diaper", "wipes", "face wash", "body wash",
                        "hand cream", "makeup", "lipstick", "hair", "nail"]
    ]

    static func predict(_ text: String) -> CategoryPrediction {
        let lower = text.lowercased()
        var bestCategory = ItemCategory.pantry
        var bestScore = 0
        for category in ItemCategory.allCases {
            var score = 0
            for word in keywords[category] ?? [] where lower.contains(word) {
                // Two-word keywords like "dish soap" count more
                score += word.contains(" ") ? 3 : 1
            }
            if score > bestScore {
                bestScore = score
                bestCategory = category
            }
        }
        let confidence = bestScore == 0 ? 0.3 : min(0.9, 0.6 + Double(bestScore) * 0.1)
        return CategoryPrediction(category: bestCategory, confidence: confidence)
    }
}
