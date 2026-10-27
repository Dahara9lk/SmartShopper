//
//  StoreMatcher.swift
//  SmartShopper
//
//  The "smart" part of Smart Map:
//  Core ML gives every list item a category -> each category maps to shop types ->
//  each shop found by MapKit gets the remaining items it can supply -> shops are ranked.
//
//  Pure functions (no UI, no network) so it is easy to unit test.
//

import Foundation

enum StoreMatcher {

    /// Shop types we need to search for, based on what is still left to buy.
    static func neededStoreTypes(for items: [ShoppingItem]) -> [StoreType] {
        let remaining = items.filter { !$0.isPurchased }
        if remaining.isEmpty { return [.supermarket] }
        var types: [StoreType] = []
        for item in remaining {
            for type in item.category.storeTypes where !types.contains(type) {
                types.append(type)
            }
        }
        return types
    }

    /// Remaining items that a shop of this type can supply.
    static func matchedItems(for type: StoreType, in items: [ShoppingItem]) -> [ShoppingItem] {
        items.filter { !$0.isPurchased && $0.category.storeTypes.contains(type) }
    }

    /// Score from 0 to 1.
    /// 70% = how much of the remaining list the shop covers, 30% = how close it is.
    static func score(matchedCount: Int, remainingCount: Int, distanceMeters: Double, radiusMeters: Double) -> Double {
        guard remainingCount > 0, radiusMeters > 0 else { return 0 }
        let coverage = Double(matchedCount) / Double(remainingCount)
        let closeness = max(0, 1 - distanceMeters / radiusMeters)
        return coverage * 0.7 + closeness * 0.3
    }

    /// Adds matched items + score to every shop and sorts best first.
    /// Shops that match nothing are dropped.
    static func rank(_ stores: [NearbyStore], items: [ShoppingItem], radiusMeters: Double) -> [NearbyStore] {
        let remainingCount = items.filter { !$0.isPurchased }.count
        var ranked: [NearbyStore] = []
        for var store in stores {
            store.matchedItems = matchedItems(for: store.type, in: items)
            guard !store.matchedItems.isEmpty || remainingCount == 0 else { continue }
            store.matchScore = score(matchedCount: store.matchedItems.count,
                                     remainingCount: max(remainingCount, 1),
                                     distanceMeters: store.distanceMeters,
                                     radiusMeters: radiusMeters)
            ranked.append(store)
        }
        return ranked.sorted {
            if $0.matchScore == $1.matchScore { return $0.distanceMeters < $1.distanceMeters }
            return $0.matchScore > $1.matchScore
        }
    }

    /// Items that NO shop in the results can supply (Figma "Item Availability Alert").
    static func unmatchedItems(_ items: [ShoppingItem], stores: [NearbyStore]) -> [ShoppingItem] {
        let covered = Set(stores.flatMap { $0.matchedItems.map(\.id) })
        return items.filter { !$0.isPurchased && !covered.contains($0.id) }
    }
}
