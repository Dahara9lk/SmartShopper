//
//  ItemClassifierService.swift
//  SmartShopper
//
//  ON-DEVICE MACHINE LEARNING with Core ML.
//
//  ItemCategoryClassifier.mlmodel (in Resources) was trained on ~790 labelled shopping
//  items (see MLTraining/train_item_classifier.py). Xcode turns the .mlmodel file into a
//  Swift class called ItemCategoryClassifier automatically.
//
//  Flow:  "oat milk"  ->  TextFeatures  ->  Core ML model  ->  .dairy (91%)
//  No internet is used - the prediction runs on the iPhone.
//

import Foundation
import CoreML

/// Result of one prediction.
struct CategoryPrediction: Equatable {
    let category: ItemCategory
    /// 0...1 - how sure the model is.
    let confidence: Double

    /// "91%"
    var confidenceText: String { "\(Int((confidence * 100).rounded()))%" }

    /// Below this we tell the user to double-check the category.
    var isLowConfidence: Bool { confidence < 0.45 }
}

/// Builds the model input. MUST match make_features() in train_item_classifier.py:
/// every word becomes "w:word" and every 3 and 4 letter chunk of "#word#" becomes "c:chunk".
enum TextFeatures {

    static func words(in text: String) -> [String] {
        let lower = text.lowercased()
        return lower
            .split(whereSeparator: { !($0.isASCII && ($0.isLetter || $0.isNumber)) })
            .map(String.init)
    }

    static func make(from text: String) -> [String: Double] {
        var features: [String: Double] = [:]
        for word in words(in: text) {
            features["w:" + word] = 1.0
            let padded = Array("#" + word + "#")
            for size in [3, 4] where padded.count >= size {
                for start in 0...(padded.count - size) {
                    let chunk = String(padded[start..<(start + size)])
                    features["c:" + chunk] = 1.0
                }
            }
        }
        return features
    }
}

final class ItemClassifierService {

    static let shared = ItemClassifierService()

    /// The Xcode-generated Core ML class. nil only if the model file is missing.
    private let model: ItemCategoryClassifier?

    init() {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly   // tiny model - CPU is fastest
        model = try? ItemCategoryClassifier(configuration: config)
    }

    var isModelLoaded: Bool { model != nil }

    /// Predicts the shop category for an item name. Returns nil for empty text.
    func predict(_ itemName: String) -> CategoryPrediction? {
        let features = TextFeatures.make(from: itemName)
        guard !features.isEmpty, let model else { return nil }
        guard let output = try? model.prediction(tokens: features) else { return nil }

        let category = ItemCategory(rawValue: output.label) ?? .pantry
        return CategoryPrediction(category: category,
                                  confidence: Self.confidence(of: output.label, in: output.labelProbability))
    }

    /// The model gives each category a 0...1 score (a sigmoid). To get a proper percentage
    /// we turn each score back into its raw value and apply softmax, so all categories add up to 100%.
    static func confidence(of label: String, in scores: [String: Double]) -> Double {
        let raw = scores.mapValues { score -> Double in
            let p = min(max(score, 1e-9), 1 - 1e-9)
            return log(p / (1 - p))
        }
        let biggest = raw.values.max() ?? 0
        let exps = raw.mapValues { exp($0 - biggest) }
        let total = exps.values.reduce(0, +)
        return total > 0 ? (exps[label] ?? 0) / total : 0
    }
}
