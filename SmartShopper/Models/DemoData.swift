//
//  DemoData.swift
//  SmartShopper
//
//  Sample content: "Popular Household Staples" grid, quick-pick chips,
//  and the "Load Demo History Data" button on the empty History screen.
//

import Foundation

struct Staple: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let category: ItemCategory
}

enum DemoData {

    /// Figma S6 "Popular Household Staples"
    static let staples: [Staple] = [
        Staple(name: "Whole Milk", detail: "Dairy • 1 gal", category: .dairy),
        Staple(name: "Organic Eggs", detail: "Farm Fresh • 12", category: .dairy),
        Staple(name: "Sourdough", detail: "Bakery • 1 loaf", category: .bakery),
        Staple(name: "Bananas", detail: "Produce • 1 bunch", category: .produce),
        Staple(name: "Ground Coffee", detail: "Dark Roast • 12oz", category: .pantry),
        Staple(name: "Olive Oil", detail: "Extra Virgin • 500ml", category: .pantry)
    ]

    /// Figma S5 "Quick" chips on the Add Item screen
    static let quickPicks = ["Almond Milk", "Sourdough Bread", "Organic Eggs", "Bananas", "Dish Soap"]

    /// 4 trips over the last 2 weeks for the History charts.
    static func sampleTrips(userName: String) -> [ShoppingTrip] {
        let calendar = Calendar.current
        func daysAgo(_ days: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return calendar.date(bySettingHour: hour, minute: 15, second: 0, of: day) ?? day
        }
        func item(_ name: String, _ category: ItemCategory, _ price: Double, by: String? = nil) -> TripItem {
            TripItem(name: name, category: category, price: price, quantity: 1, addedByName: by ?? userName)
        }
        return [
            ShoppingTrip(storeName: "GreenValley Organic Grocer", storeArea: "Market District",
                         date: daysAgo(1, hour: 17),
                         items: [item("Whole Milk", .dairy, 3.49), item("Sourdough Bread", .bakery, 4.20),
                                 item("Organic Spinach", .produce, 2.99), item("Hass Avocados", .produce, 3.50, by: "Alex"),
                                 item("Chia Seeds", .pantry, 5.80), item("Greek Yogurt", .dairy, 4.10, by: "Mom"),
                                 item("Pasture Eggs", .dairy, 3.29), item("Dark Chocolate 70%", .pantry, 3.89, by: "Mom")],
                         plannedCount: 8, durationMinutes: 18, minutesSaved: 18, familyMemberCount: 4),
            ShoppingTrip(storeName: "Artisan Crust & Dairy", storeArea: "North Boulevard",
                         date: daysAgo(6, hour: 13),
                         items: [item("Sourdough Loaf", .bakery, 6.50), item("Salted Cream Butter", .dairy, 4.80),
                                 item("Farm Eggs", .dairy, 4.30), item("French Croissant", .bakery, 6.50)],
                         plannedCount: 5, durationMinutes: 12, minutesSaved: 9),
            ShoppingTrip(storeName: "TechHub & Essentials", storeArea: "West Mall Fl. 2",
                         date: daysAgo(9, hour: 18),
                         items: [item("USB-C Braided Cable (2m)", .electronics, 19.90),
                                 item("AA Lithium Batteries 8-pk", .household, 14.00),
                                 item("Screen Microfiber Wipes", .electronics, 11.00)],
                         plannedCount: 3, durationMinutes: 10, minutesSaved: 6),
            ShoppingTrip(storeName: "Downtown Superstore", storeArea: "Main Atrium",
                         date: daysAgo(13, hour: 11),
                         items: [item("Almond Butter", .pantry, 9.50), item("Olive Oil 1L", .pantry, 12.40),
                                 item("Dish Soap", .household, 3.80), item("Kitchen Towels", .household, 6.20),
                                 item("Sparkling Water 12pk", .pantry, 8.90), item("Herbal Shampoo", .personalCare, 7.40),
                                 item("Toothpaste", .personalCare, 3.20), item("Brown Rice", .pantry, 4.60),
                                 item("Bananas", .produce, 2.10), item("Ground Coffee", .pantry, 11.20),
                                 item("Paper Towels", .household, 5.10), item("Cheddar Cheese", .dairy, 4.80)],
                         plannedCount: 14, durationMinutes: 31, minutesSaved: 12)
        ]
    }
}
