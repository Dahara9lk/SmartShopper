//
//  SmartShopperApp.swift
//  SmartShopper
//
//  App entry point (the only @main in the project).
//

import SwiftUI

@main
struct SmartShopperApp: App {

    // Shared objects, created once in AppEnvironment and passed down to every view.
    @StateObject private var settings: SettingsStore
    @StateObject private var store: AppDataStore
    @StateObject private var security: SecurityViewModel
    @StateObject private var router: AppRouter
    @StateObject private var location: LocationService
    @StateObject private var smartMap: SmartMapViewModel
    @StateObject private var network: NetworkMonitor
    @StateObject private var geofence: GeofenceService

    init() {
        let env = AppEnvironment.shared
        _settings = StateObject(wrappedValue: env.settings)
        _store = StateObject(wrappedValue: env.store)
        _security = StateObject(wrappedValue: env.security)
        _router = StateObject(wrappedValue: env.router)
        _location = StateObject(wrappedValue: env.location)
        _smartMap = StateObject(wrappedValue: env.smartMap)
        _network = StateObject(wrappedValue: env.network)
        _geofence = StateObject(wrappedValue: env.geofence)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(security)
                .environmentObject(router)
                .environmentObject(location)
                .environmentObject(smartMap)
                .environmentObject(network)
                .environmentObject(geofence)
                // Light / Dark / System from Profile settings
                .preferredColorScheme(settings.colorScheme)
                .tint(.brandPrimary)
        }
    }
}
