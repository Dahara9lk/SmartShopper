//
//  HistoryViewModel.swift
//  SmartShopper
//
//  Numbers for the History & Statistics screen
//  A plain struct: give it the trips, read the stats. Easy to unit test.
//

import Foundation

struct HistoryStats {

    struct DayCount: Identifiable {
        let id: Int          // 1 = Monday ... 7 = Sunday
        let label: String    // "M", "T"...
        let trips: Int
    }

    struct CategoryShare: Identifiable {
        var id: String { category.rawValue }
        let category: ItemCategory
        let count: Int
        let share: Double    // 0...1
    }

    let trips: [ShoppingTrip]

    var tripCount: Int { trips.count }

    var itemsCollected: Int { trips.reduce(0) { $0 + $1.items.count } }

    var totalSpend: Double { trips.reduce(0) { $0 + $1.total } }

    var averagePerTrip: Double { tripCount == 0 ? 0 : totalSpend / Double(tripCount) }

    // Average completion across trips, 0...1
    var averageCompletion: Double {
        guard !trips.isEmpty else { return 0 }
        return trips.reduce(0) { $0 + $1.completionRate } / Double(trips.count)
    }

    // Total minutes saved, shown as hours ("4.2 hrs").
    var hoursSaved: Double { Double(trips.reduce(0) { $0 + $1.minutesSaved }) / 60 }

    // Trips in the last 30 days ("+4 this mo").
    func tripsThisMonth(now: Date = Date()) -> Int {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        return trips.filter { $0.date >= start }.count
    }

    // Trips per weekday, Monday first (for the Weekly Shopping Intensity chart).
    var tripsByWeekday: [DayCount] {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        var counts = Array(repeating: 0, count: 7)
        for trip in trips {
            // Calendar weekday: 1 = Sunday ... 7 = Saturday  ->  convert to Monday = 0
            let weekday = Calendar.current.component(.weekday, from: trip.date)
            let index = (weekday + 5) % 7
            counts[index] += 1
        }
        return (0..<7).map { DayCount(id: $0 + 1, label: labels[$0], trips: counts[$0]) }
    }

    // Busiest day name ("Saturday").
    var peakDay: String? {
        guard let best = tripsByWeekday.max(by: { $0.trips < $1.trips }), best.trips > 0 else { return nil }
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names[best.id - 1]
    }

    // Category Distribution bar - biggest first.
    var categoryShares: [CategoryShare] {
        let all = trips.flatMap { $0.items }
        guard !all.isEmpty else { return [] }
        return ItemCategory.allCases.compactMap { category -> CategoryShare? in
            let count = all.filter { $0.category == category }.count
            guard count > 0 else { return nil }
            return CategoryShare(category: category, count: count, share: Double(count) / Double(all.count))
        }
        .sorted { $0.count > $1.count }
    }

    // Milestone card text.
    var milestoneText: String? {
        guard tripCount >= 3 else { return nil }
        let percent = Int((averageCompletion * 100).rounded())
        return "You completed \(percent)% of planned shopping items across \(tripCount) trips. Keep it up!"
    }
}
