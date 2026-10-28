//
//  AppEnvironment.swift
//  SmartShopper

import Foundation
import FirebaseCore

@MainActor
final class AppEnvironment {

    static let shared = AppEnvironment()

    let settings: SettingsStore
    let store: AppDataStore
    let security: SecurityViewModel
    let router: AppRouter
    let location: LocationService
    let geofence: GeofenceService
    let smartMap: SmartMapViewModel
    let network: NetworkMonitor
    let isFirebaseConfigured: Bool

    private init() {
        // 1. Firebase
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            isFirebaseConfigured = true
        } else {
            isFirebaseConfigured = false
            print("⚠️ GoogleService-Info.plist not found - SmartShopper is running in DEMO MODE (local data).")
        }

        // 2. Services
        settings = SettingsStore()
        let auth: AuthServiceProtocol = isFirebaseConfigured ? FirebaseAuthService() : LocalAuthService()
        let data: DataServiceProtocol = isFirebaseConfigured ? FirebaseDataService() : LocalDataService()

        // 3. Shared view models
        store = AppDataStore(auth: auth, data: data, settings: settings, isDemoMode: !isFirebaseConfigured)
        security = SecurityViewModel(settings: settings)
        router = AppRouter()
        location = LocationService()
        geofence = GeofenceService(settings: settings)
        smartMap = SmartMapViewModel(location: location, geofence: geofence, settings: settings)
        network = NetworkMonitor()

        // 4. Notifications
        NotificationService.shared.configure()
        NotificationService.shared.scheduleWeeklyRecap(enabled: settings.weeklyRecap)
    }
}
