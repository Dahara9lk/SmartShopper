//
//  ListAndHistoryTests.swift
//  SmartShopperTests
//
//  List maths (filters, progress, totals, aisle order), In-Store Mode and History stats.
//

import Foundation
import Testing
@testable import SmartShopper

@Suite("Shopping list maths")
struct ListMathTests {

    private let items = [
        TestData.item("Milk", category: .dairy, price: 3.5),
        TestData.item("Bread", category: .bakery, price: 4.0, purchased: true),
        TestData.item("Spinach", category: .produce, price: 2.0, quantity: 2),
        TestData.item("Cheese", category: .dairy, price: 5.0)
    ]

    @Test("Filtering by category")
    func filtering() {
        #expect(ListsViewModel.filter(items, by: nil).count == 4)
        #expect(ListsViewModel.filter(items, by: .dairy).map(\.name) == ["Milk", "Cheese"])
        #expect(ListsViewModel.filter(items, by: .electronics).isEmpty)
    }

    @Test("Chip counts only list categories that have items")
    func chipCounts() {
        let counts = ListsViewModel.categoryCounts(items)
        #expect(counts.count == 3)
        #expect(counts.first { $0.category == .dairy }?.count == 2)
    }

    @Test("Progress is purchased / total and 0 for an empty list")
    func progress() {
        #expect(ListsViewModel.progress(items) == 0.25)
        #expect(ListsViewModel.progress([]) == 0)
    }

    @Test("Estimated total uses price x quantity")
    func total() {
        // 3.5 + 4.0 + (2.0 x 2) + 5.0
        #expect(ListsViewModel.estimatedTotal(items) == 16.5)
    }

    @Test("Aisle order skips purchased items and sorts by aisle")
    func aisleOrder() {
        let ordered = ListsViewModel.aisleOrdered(items).map(\.name)
        #expect(ordered == ["Spinach", "Cheese", "Milk"])   // produce (1) then dairy (3), A-Z inside an aisle
    }

    @Test("Quantity text")
    func quantityText() {
        var item = TestData.item("Milk")
        #expect(item.quantityText == "1 unit")
        item.quantity = 2
        item.unit = .liters
        #expect(item.quantityText == "2 L")
        #expect(item.titleWithQuantity == "Milk — 2 L")
    }
}

@Suite("In-Store Shopping Mode")
@MainActor
struct InStoreTests {

    private func makeViewModel() -> InStoreViewModel {
        InStoreViewModel(items: [
            TestData.item("Milk", category: .dairy, price: 3),
            TestData.item("Apples", category: .produce, price: 2),
            TestData.item("Bread", category: .bakery, price: 4),
            TestData.item("Rice", category: .pantry, price: 5, purchased: true)
        ], storeName: "GreenValley", storeArea: "Colombo")
    }

    @Test("Starts at the first aisle and ignores purchased items")
    func startsInAisleOrder() {
        let vm = makeViewModel()
        #expect(vm.plannedCount == 3)
        #expect(vm.current?.name == "Apples")
        #expect(vm.basketTotal == 0)
    }

    @Test("Put in Basket moves to the next item and adds to the total")
    func putInBasket() {
        let vm = makeViewModel()
        vm.putInBasket()
        #expect(vm.current?.name == "Bread")
        #expect(vm.pickedCount == 1)
        #expect(vm.basketTotal == 2)
        #expect(abs(vm.progress - 1.0 / 3.0) < 0.0001)
    }

    @Test("Skip keeps the item off the basket")
    func skip() {
        let vm = makeViewModel()
        vm.skip()
        #expect(vm.skipped.map(\.name) == ["Apples"])
        #expect(vm.pickedCount == 0)
    }

    @Test("Finishing every item empties the queue; unpick puts it back")
    func finishAndUnpick() throws {
        let vm = makeViewModel()
        vm.putInBasket()
        vm.putInBasket()
        vm.putInBasket()
        #expect(vm.isFinished)
        #expect(vm.basketTotal == 9)
        let milk = try #require(vm.picked.first { $0.name == "Milk" })
        vm.unpick(milk)
        #expect(vm.current?.name == "Milk")
        #expect(vm.basketTotal == 6)
    }

    @Test("Store path starts at the entrance and ends at checkout")
    func pathStops() {
        let vm = makeViewModel()
        #expect(vm.pathStops.first == "Entrance")
        #expect(vm.pathStops.last == "Checkout")
        #expect(vm.pathStops.contains("Aisle 1"))
    }
}

@Suite("History statistics")
struct HistoryStatsTests {

    private let trips = [
        TestData.trip(daysAgo: 1, items: [TestData.tripItem("Milk", .dairy, 3), TestData.tripItem("Bread", .bakery, 4)],
                      planned: 2, saved: 30),
        TestData.trip(daysAgo: 40, items: [TestData.tripItem("Cable", .electronics, 10)], planned: 2, saved: 30)
    ]

    @Test("Totals")
    func totals() {
        let stats = HistoryStats(trips: trips)
        #expect(stats.tripCount == 2)
        #expect(stats.itemsCollected == 3)
        #expect(stats.totalSpend == 17)
        #expect(stats.averagePerTrip == 8.5)
        #expect(stats.hoursSaved == 1)
    }

    @Test("Completion averages each trip (100% and 50%)")
    func completion() {
        #expect(HistoryStats(trips: trips).averageCompletion == 0.75)
    }

    @Test("Only trips from the last 30 days count as this month")
    func thisMonth() {
        #expect(HistoryStats(trips: trips).tripsThisMonth() == 1)
    }

    @Test("Weekday chart always has 7 days and adds up to the trip count")
    func weekdays() {
        let days = HistoryStats(trips: trips).tripsByWeekday
        #expect(days.count == 7)
        #expect(days.reduce(0) { $0 + $1.trips } == 2)
        #expect(days.first?.label == "M")
    }

    @Test("Category shares add up to 100%")
    func shares() {
        let shares = HistoryStats(trips: trips).categoryShares
        let total = shares.reduce(0) { $0 + $1.share }
        #expect(abs(total - 1) < 0.0001)
        #expect(shares.count == 3)
    }

    @Test("Empty history has safe zero values")
    func empty() {
        let stats = HistoryStats(trips: [])
        #expect(stats.averagePerTrip == 0)
        #expect(stats.averageCompletion == 0)
        #expect(stats.peakDay == nil)
        #expect(stats.categoryShares.isEmpty)
        #expect(stats.milestoneText == nil)
    }

    @Test("CSV export has a header, one row per item and escapes commas")
    func csv() {
        let trip = TestData.trip(daysAgo: 0, items: [TestData.tripItem("Cheese, Cheddar", .dairy, 4.8)], planned: 1)
        let lines = CSVExporter.makeCSV(trips: [trip]).split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("Date,Store,Item"))
        #expect(lines[1].contains("\"Cheese, Cheddar\""))
        #expect(lines[1].contains("4.80"))
    }
}
