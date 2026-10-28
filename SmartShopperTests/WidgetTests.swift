//
//  WidgetTests.swift
//  SmartShopperTests
//
//  The summary the app saves for the Home Screen / Lock Screen widget.
//

import Testing
@testable import SmartShopper

@Suite("Widget snapshot")
@MainActor   // the app target uses MainActor as its default isolation
struct WidgetTests {

    @Test("Counts only items still to buy and lists the first three")
    func countsRemaining() {
        let items = [
            TestData.item("Milk", category: .dairy, price: 2),
            TestData.item("Bread", category: .bakery, price: 3),
            TestData.item("Soap", category: .household, price: 1, purchased: true),
            TestData.item("Rice", category: .pantry, price: 4, family: true),
            TestData.item("Eggs", category: .dairy, price: 5)
        ]
        let snapshot = WidgetBridge.makeSnapshot(items: items, keeping: .empty)
        #expect(snapshot.itemsLeft == 4)
        #expect(snapshot.nextItems == ["Milk", "Bread", "Rice"])
        #expect(snapshot.familyItemsLeft == 1)
        #expect(snapshot.totalText == AppFormat.money(14))
    }

    @Test("An empty list clears the best shop")
    func emptyListClearsShop() {
        var old = WidgetSnapshot.sample
        old.bestShopName = "SPAR"
        let snapshot = WidgetBridge.makeSnapshot(items: [], keeping: old)
        #expect(snapshot.itemsLeft == 0)
        #expect(snapshot.nextItems.isEmpty)
        #expect(snapshot.bestShopName == nil)
    }

    @Test("Best shop is kept while items remain")
    func keepsShop() {
        var old = WidgetSnapshot.empty
        old.bestShopName = "Keells"
        old.bestShopMatches = 2
        let snapshot = WidgetBridge.makeSnapshot(items: [TestData.item("Milk")], keeping: old)
        #expect(snapshot.bestShopName == "Keells")
        #expect(snapshot.bestShopMatches == 2)
    }
}
