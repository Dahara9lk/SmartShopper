//
//  NotificationService.swift
//  SmartShopper
//
//  Notifications with Apple's UserNotifications framework:
//   - store alerts when you enter a geofence around a matched shop (GeofenceService)
//   - family alerts when someone adds / checks off an item (AppDataStore)
//   - weekly shopping recap every Sunday evening
//   - "Send Test Notification" button in settings
//
//  These are local notifications created on the phone. (Remote APNs push needs a paid
//  Apple Developer account, so the family alerts are raised by the Firestore listener instead.)
//

import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a store notification - MainTabView opens the Smart Map tab.
    static let openSmartMap = Notification.Name("openSmartMap")
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // Notification categories and buttons (shown when you long-press the banner)
    static let storeCategory = "STORE_ALERT"
    static let snoozeAction = "SNOOZE_10"
    static let routeAction = "SHOP_ROUTE"
    private static let weeklyRecapId = "weekly-recap"

    /// Call once when the app starts.
    func configure() {
        center.delegate = self
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze 10m", options: [])
        let route = UNNotificationAction(identifier: Self.routeAction, title: "Shop & Route", options: [.foreground])
        let storeCategory = UNNotificationCategory(identifier: Self.storeCategory,
                                                   actions: [snooze, route],
                                                   intentIdentifiers: [],
                                                   options: [])
        center.setNotificationCategories([storeCategory])
    }

    // MARK: Permission

    /// Shows the iOS "Allow Notifications?" popup (only the first time).
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: Sending

    /// "GreenValley Grocer is 350 m away - 3 items on your list: Milk, Bread, Eggs"
    func sendStoreAlert(storeName: String, itemNames: [String], storeId: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(storeName) is nearby"
        let list = itemNames.prefix(3).joined(separator: ", ")
        content.body = "\(itemNames.count) item\(itemNames.count == 1 ? "" : "s") on your list: \(list)"
        content.sound = .default
        content.categoryIdentifier = Self.storeCategory
        content.userInfo = ["storeId": storeId]
        send(content, id: "store-\(storeId)")
    }

    /// "Mom added Oat Milk"
    func sendFamilyAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        send(content, id: UUID().uuidString)
    }

    /// Button in Notification Settings - fires after 3 seconds so you can lock the simulator.
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "SmartShopper test alert"
        content.body = "GreenValley Organic Grocer is 350 m ahead. 3 items on your list are in stock."
        content.sound = .default
        content.categoryIdentifier = Self.storeCategory
        content.userInfo = ["storeId": "test"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        center.add(UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger))
    }

    /// Weekly recap every Sunday at 6 PM (or removes it when switched off).
    func scheduleWeeklyRecap(enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapId])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your weekly shopping recap"
        content.body = "See what you bought this week and plan next week's list."
        content.sound = .default
        var date = DateComponents()
        date.weekday = 1   // Sunday
        date.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        center.add(UNNotificationRequest(identifier: Self.weeklyRecapId, content: content, trigger: trigger))
    }

    /// Shows a notification straight away (1 second trigger).
    private func send(_ content: UNMutableNotificationContent, id: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Called when the user taps the notification or one of its buttons.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        switch response.actionIdentifier {
        case Self.snoozeAction:
            // Same alert again in 10 minutes
            guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: copy, trigger: trigger))
        default:
            if content.categoryIdentifier == Self.storeCategory {
                await MainActor.run {
                    NotificationCenter.default.post(name: .openSmartMap, object: nil)
                }
            }
        }
    }
}
