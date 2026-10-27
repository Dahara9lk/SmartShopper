//
//  StoreMatcherTests.swift
//  SmartShopperTests
//
//  Smart Map ranking: which shops are searched for, what they match, and the order.
//

import Testing
@testable import SmartShopper

@Suite("Smart Map store matching")
struct StoreMatcherTests {

    private let items = [
        TestData.item("Milk", category: .dairy),
        TestData.item("Bread", category: .bakery),
        TestData.item("USB-C Cable", category: .electronics),
        TestData.item("Panadol", category: .pharmacy),
        TestData.item("Eggs", category: .dairy, purchased: true)       // already bought - ignored
    ]

    @Test("Only shop types needed for remaining items are searched")
    func neededTypes() {
        let types = StoreMatcher.neededStoreTypes(for: items)
        #expect(Set(types) == [.supermarket, .bakery, .electronics, .pharmacy])
    }

    @Test("An empty list still looks for supermarkets")
    func emptyListTypes() {
        #expect(StoreMatcher.neededStoreTypes(for: []) == [.supermarket])
    }

    @Test("A supermarket matches dairy and bakery, but not purchased items")
    func supermarketMatches() {
        let matched = StoreMatcher.matchedItems(for: .supermarket, in: items).map(\.name)
        #expect(Set(matched) == ["Milk", "Bread"])
    }

    @Test("Score: more coverage and closer shops score higher")
    func scoring() {
        let near = StoreMatcher.score(matchedCount: 2, remainingCount: 4, distanceMeters: 100, radiusMeters: 5000)
        let far = StoreMatcher.score(matchedCount: 2, remainingCount: 4, distanceMeters: 4900, radiusMeters: 5000)
        let better = StoreMatcher.score(matchedCount: 4, remainingCount: 4, distanceMeters: 4900, radiusMeters: 5000)
        #expect(near > far)
        #expect(better > near)
        #expect(StoreMatcher.score(matchedCount: 1, remainingCount: 0, distanceMeters: 0, radiusMeters: 1) == 0)
    }

    @Test("Ranking puts the best match first and drops shops that match nothing")
    func ranking() {
        let stores = [
            TestData.store("Pharmacy", type: .pharmacy, distance: 300),
            TestData.store("SuperMart", type: .supermarket, distance: 800),
            TestData.store("Bakery", type: .bakery, distance: 200)
        ]
        let noMatch = [TestData.item("Cable", category: .electronics)]
        #expect(StoreMatcher.rank(stores, items: noMatch, radiusMeters: 5000).isEmpty)

        let ranked = StoreMatcher.rank(stores, items: items, radiusMeters: 5000)
        #expect(ranked.first?.name == "SuperMart")        // covers 2 of 4 items
        #expect(ranked.count == 3)
        #expect(ranked.first?.matchedItems.count == 2)
    }

    @Test("Items no shop can supply are reported")
    func unmatched() {
        let stores = StoreMatcher.rank([TestData.store("SuperMart", type: .supermarket, distance: 500)],
                                       items: items, radiusMeters: 5000)
        let missing = StoreMatcher.unmatchedItems(items, stores: stores).map(\.name)
        #expect(Set(missing) == ["USB-C Cable", "Panadol"])
    }
}
