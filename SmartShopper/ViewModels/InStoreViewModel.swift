//
//  InStoreViewModel.swift
//  SmartShopper
//
//  In-Store Shopping Mode: walks the user through the list in aisle order,
//  one "waypoint" at a time, with a running basket total.
//

import Foundation

@MainActor
final class InStoreViewModel: ObservableObject {

    @Published private(set) var queue: [ShoppingItem]          // still to pick, aisle order
    @Published private(set) var picked: [ShoppingItem] = []
    @Published private(set) var skipped: [ShoppingItem] = []

    let storeName: String
    let storeArea: String
    let plannedCount: Int
    private let startedAt = Date()

    init(items: [ShoppingItem], storeName: String, storeArea: String) {
        let ordered = ListsViewModel.aisleOrdered(items)
        self.queue = ordered
        self.plannedCount = ordered.count
        self.storeName = storeName
        self.storeArea = storeArea
    }

    // The item to pick now ("Immediate Waypoint").
    var current: ShoppingItem? { queue.first }

    // Items after the current one, grouped by aisle for "Upcoming Aisle Waypoints".
    var upcomingByAisle: [(aisle: Int, title: String, items: [ShoppingItem])] {
        let upcoming = Array(queue.dropFirst())
        let aisles = Array(Set(upcoming.map { $0.category.aisle })).sorted()
        return aisles.map { aisle -> (aisle: Int, title: String, items: [ShoppingItem]) in
            let items = upcoming.filter { $0.category.aisle == aisle }
            return (aisle, "Aisle \(aisle) — \(items.first?.category.title ?? "")", items)
        }
    }

    var pickedCount: Int { picked.count }
    var progress: Double { plannedCount == 0 ? 0 : Double(picked.count) / Double(plannedCount) }
    var basketTotal: Double { picked.reduce(0) { $0 + $1.lineTotal } }
    var isFinished: Bool { queue.isEmpty }

    // About 1.5 minutes per remaining item.
    var minutesLeft: Int { Int((Double(queue.count) * 1.5).rounded(.up)) }

    // Aisles for the "Store Path Radar" strip: entrance, each aisle, checkout.
    var pathStops: [String] {
        let aisles = Array(Set((picked + queue + skipped).map { $0.category.aisle })).sorted()
        return ["Entrance"] + aisles.map { "Aisle \($0)" } + ["Checkout"]
    }

    // Index of the stop the user is at now (for the radar dot).
    var currentStopIndex: Int {
        guard let current else { return pathStops.count - 1 }
        return (pathStops.firstIndex(of: "Aisle \(current.category.aisle)") ?? 0)
    }

    // "Put in Basket"
    func putInBasket() {
        guard let item = queue.first else { return }
        queue.removeFirst()
        picked.append(item)
    }

    // "Skip or Out" - not available here, keep it on the list.
    func skip() {
        guard let item = queue.first else { return }
        queue.removeFirst()
        skipped.append(item)
    }

    // Tick an upcoming item directly from the aisle list.
    func pick(_ item: ShoppingItem) {
        guard let index = queue.firstIndex(of: item) else { return }
        queue.remove(at: index)
        picked.append(item)
    }

    // Undo a pick.
    func unpick(_ item: ShoppingItem) {
        guard let index = picked.firstIndex(of: item) else { return }
        picked.remove(at: index)
        queue.append(item)
        queue = ListsViewModel.aisleOrdered(queue)
    }

    var durationMinutes: Int {
        max(1, Int(Date().timeIntervalSince(startedAt) / 60))
    }
}
