//
//  DemoData.swift
//  SmartShopper

import Foundation

struct Staple: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let category: ItemCategory
}

enum DemoData {

   
    static let staples: [Staple] = [
        Staple(name: "Fresh Milk", detail: "Dairy • 1 L", category: .dairy),
        Staple(name: "Eggs", detail: "Farm Fresh • 10", category: .dairy),
        Staple(name: "Sandwich Bread", detail: "Bakery • 1 loaf", category: .bakery),
        Staple(name: "Bananas", detail: "Produce • 1 bunch", category: .produce),
        Staple(name: "Ceylon Tea", detail: "Pantry • 200 g", category: .pantry),
        Staple(name: "Red Rice", detail: "Pantry • 1 kg", category: .pantry)
    ]

   
    static let quickPicks = ["Fresh Milk", "Bread", "Eggs", "Bananas", "Dish Soap"]

    
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
            ShoppingTrip(storeName: "Keells Super", storeArea: "Union Place, Colombo 02",
                         date: daysAgo(1, hour: 17),
                         items: [item("Fresh Milk 1L", .dairy, 480), item("Sandwich Bread", .bakery, 220),
                                 item("Carrots 500g", .produce, 290), item("Bananas", .produce, 260, by: "Alex"),
                                 item("Red Rice 1kg", .pantry, 310), item("Curd Pot", .dairy, 650, by: "Mom"),
                                 item("Eggs 10-pk", .dairy, 520), item("Chocolate Bar", .pantry, 450, by: "Mom")],
                         plannedCount: 8, durationMinutes: 18, minutesSaved: 18, familyMemberCount: 4),
            ShoppingTrip(storeName: "Perera & Sons Bakery", storeArea: "Maradana",
                         date: daysAgo(6, hour: 13),
                         items: [item("Butter Cake", .bakery, 780), item("Anchor Butter", .dairy, 1250),
                                 item("Farm Eggs", .dairy, 520), item("Fish Buns", .bakery, 360)],
                         plannedCount: 5, durationMinutes: 12, minutesSaved: 9),
            ShoppingTrip(storeName: "Singer Mega", storeArea: "Borella",
                         date: daysAgo(9, hour: 18),
                         items: [item("USB-C Cable (2m)", .electronics, 2490),
                                 item("AA Batteries 4-pk", .household, 990),
                                 item("Screen Wipes", .electronics, 750)],
                         plannedCount: 3, durationMinutes: 10, minutesSaved: 6),
            ShoppingTrip(storeName: "Cargills Food City", storeArea: "Kollupitiya",
                         date: daysAgo(13, hour: 11),
                         items: [item("Peanut Butter", .pantry, 1150), item("Coconut Oil 1L", .pantry, 980),
                                 item("Dish Wash Liquid", .household, 420), item("Kitchen Towels", .household, 560),
                                 item("Soda 1.5L", .pantry, 380), item("Herbal Shampoo", .personalCare, 890),
                                 item("Toothpaste", .personalCare, 340), item("Basmati Rice 1kg", .pantry, 720),
                                 item("Bananas", .produce, 260), item("Ceylon Tea 200g", .pantry, 650),
                                 item("Toilet Paper 4-roll", .household, 590), item("Cheddar Cheese", .dairy, 1350)],
                         plannedCount: 14, durationMinutes: 31, minutesSaved: 12)
        ]
    }
}
