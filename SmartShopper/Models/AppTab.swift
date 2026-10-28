//
//  AppTab.swift
//  SmartShopper
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case lists
    case smartMap
    case history
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .lists: return "Lists"
        case .smartMap: return "Smart Map"
        case .history: return "History"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .lists: return "checklist"
        case .smartMap: return "safari.fill"
        case .history: return "clock.arrow.circlepath"
        case .profile: return "person.crop.circle"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
