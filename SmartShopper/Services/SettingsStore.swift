//
//  SettingsStore.swift
//  SmartShopper
//
//  All user preferences (Profile + Notification settings screens).
//  Each value is saved to UserDefaults as soon as it changes, so it survives app restarts.
//

import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {

    private let defaults: UserDefaults

    // MARK: Appearance
    @Published var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }

    // MARK: Security (Face ID)
    @Published var faceIDEnabled: Bool { didSet { defaults.set(faceIDEnabled, forKey: "faceIDEnabled") } }
    @Published var protectFamilyLists: Bool { didSet { defaults.set(protectFamilyLists, forKey: "protectFamilyLists") } }
    @Published var quickAuthOnCommute: Bool { didSet { defaults.set(quickAuthOnCommute, forKey: "quickAuthOnCommute") } }
    /// Seconds in the background before the app locks again. 0 = immediately.
    @Published var lockTimeoutSeconds: Int { didSet { defaults.set(lockTimeoutSeconds, forKey: "lockTimeoutSeconds") } }
    /// Remember email + password in the Keychain so "Face ID Scan" can sign in.
    @Published var keepSignedInWithFaceID: Bool { didSet { defaults.set(keepSignedInWithFaceID, forKey: "keepSignedInWithFaceID") } }

    // MARK: Location
    /// Geofence radius around matched shops, in metres (200 / 500 / 1000 / 2500).
    @Published var alertRadiusMeters: Int { didSet { defaults.set(alertRadiusMeters, forKey: "alertRadiusMeters") } }
    @Published var alongRouteDetection: Bool { didSet { defaults.set(alongRouteDetection, forKey: "alongRouteDetection") } }

    // MARK: Notifications
    @Published var storeAlerts: Bool { didSet { defaults.set(storeAlerts, forKey: "storeAlerts") } }
    @Published var familyItemAlerts: Bool { didSet { defaults.set(familyItemAlerts, forKey: "familyItemAlerts") } }
    @Published var familyCheckedAlerts: Bool { didSet { defaults.set(familyCheckedAlerts, forKey: "familyCheckedAlerts") } }
    @Published var tripSummaryAlerts: Bool { didSet { defaults.set(tripSummaryAlerts, forKey: "tripSummaryAlerts") } }
    @Published var weeklyRecap: Bool { didSet { defaults.set(weeklyRecap, forKey: "weeklyRecap") } }
    @Published var quietHoursOn: Bool { didSet { defaults.set(quietHoursOn, forKey: "quietHoursOn") } }
    @Published var quietStartHour: Int { didSet { defaults.set(quietStartHour, forKey: "quietStartHour") } }
    @Published var quietEndHour: Int { didSet { defaults.set(quietEndHour, forKey: "quietEndHour") } }
    @Published var urgentOverride: Bool { didSet { defaults.set(urgentOverride, forKey: "urgentOverride") } }

    // MARK: Preferences
    @Published var useMetric: Bool { didSet { defaults.set(useMetric, forKey: "useMetric") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // register(defaults:) gives the starting value the first time the app runs
        defaults.register(defaults: [
            "appearance": AppearanceMode.system.rawValue,
            "faceIDEnabled": false,
            "protectFamilyLists": false,
            "quickAuthOnCommute": false,
            "lockTimeoutSeconds": 0,
            "keepSignedInWithFaceID": true,
            "alertRadiusMeters": 500,
            "alongRouteDetection": true,
            "storeAlerts": true,
            "familyItemAlerts": true,
            "familyCheckedAlerts": true,
            "tripSummaryAlerts": false,
            "weeklyRecap": true,
            "quietHoursOn": true,
            "quietStartHour": 22,
            "quietEndHour": 7,
            "urgentOverride": true,
            "useMetric": true
        ])
        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        faceIDEnabled = defaults.bool(forKey: "faceIDEnabled")
        protectFamilyLists = defaults.bool(forKey: "protectFamilyLists")
        quickAuthOnCommute = defaults.bool(forKey: "quickAuthOnCommute")
        lockTimeoutSeconds = defaults.integer(forKey: "lockTimeoutSeconds")
        keepSignedInWithFaceID = defaults.bool(forKey: "keepSignedInWithFaceID")
        alertRadiusMeters = defaults.integer(forKey: "alertRadiusMeters")
        alongRouteDetection = defaults.bool(forKey: "alongRouteDetection")
        storeAlerts = defaults.bool(forKey: "storeAlerts")
        familyItemAlerts = defaults.bool(forKey: "familyItemAlerts")
        familyCheckedAlerts = defaults.bool(forKey: "familyCheckedAlerts")
        tripSummaryAlerts = defaults.bool(forKey: "tripSummaryAlerts")
        weeklyRecap = defaults.bool(forKey: "weeklyRecap")
        quietHoursOn = defaults.bool(forKey: "quietHoursOn")
        quietStartHour = defaults.integer(forKey: "quietStartHour")
        quietEndHour = defaults.integer(forKey: "quietEndHour")
        urgentOverride = defaults.bool(forKey: "urgentOverride")
        useMetric = defaults.bool(forKey: "useMetric")
    }

    /// Turns the appearance setting into the value SwiftUI's .preferredColorScheme needs.
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// "Immediately", "After 1 minute"...
    static func lockTimeoutTitle(_ seconds: Int) -> String {
        switch seconds {
        case 0: return "Immediately"
        case 60: return "After 1 minute"
        case 300: return "After 5 minutes"
        default: return "After \(seconds / 60) minutes"
        }
    }

    /// "10:00 PM"
    static func hourTitle(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Should a notification be shown right now? (quiet hours + urgent override)
    func shouldDeliver(isUrgent: Bool, now: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return QuietHours.shouldDeliver(hour: hour,
                                        quietOn: quietHoursOn,
                                        start: quietStartHour,
                                        end: quietEndHour,
                                        isUrgent: isUrgent,
                                        urgentOverride: urgentOverride)
    }
}

/// Quiet hours maths, kept separate so it can be unit tested.
enum QuietHours {

    /// true when `hour` is inside the quiet window. Handles windows that cross midnight (22 -> 7).
    static func isQuiet(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    static func shouldDeliver(hour: Int, quietOn: Bool, start: Int, end: Int,
                              isUrgent: Bool, urgentOverride: Bool) -> Bool {
        guard quietOn, isQuiet(hour: hour, start: start, end: end) else { return true }
        return isUrgent && urgentOverride
    }
}
