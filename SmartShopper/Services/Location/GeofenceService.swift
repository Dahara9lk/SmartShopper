//
//  GeofenceService.swift
//  SmartShopper
//
//  Geofencing with Core Location's CLMonitor (iOS 17).
//  We draw an invisible circle (radius from settings: 200 m - 2.5 km) around the best
//  matched shops. When the user walks or drives INTO a circle, iOS tells us and we
//  send a local notification listing the items that shop has.
//
//  Simulator test: Features > Location > Custom Location, put a point next to a shop,
//  or use Freeway Drive / a GPX file so the location moves into the circle.
//

import Foundation
import CoreLocation

@MainActor
final class GeofenceService: ObservableObject {

    /// Shop names currently being watched (shown in Profile > Location).
    @Published private(set) var watchedStoreNames: [String] = []

    private var clMonitor: CLMonitor?
    private var eventsTask: Task<Void, Never>?
    /// storeId -> (name, item names) so the notification text is ready when the event comes in.
    private var storeInfo: [String: (name: String, items: [String])] = [:]
    /// Used to check quiet hours and whether store alerts are switched on.
    private let settings: SettingsStore

    /// iOS allows 20 monitored regions per app; we use at most 10.
    static let maxRegions = 10

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Replaces the watched shops with a new set.
    func monitor(stores: [NearbyStore], radiusMeters: Double) async {
        if clMonitor == nil {
            clMonitor = await CLMonitor("SmartShopperStores")
        }
        guard let monitor = clMonitor else { return }

        // Remove the old circles
        for identifier in await monitor.identifiers {
            await monitor.remove(identifier)
        }
        storeInfo.removeAll()

        // Add a circle for each matched shop
        let chosen = Array(stores.filter { !$0.matchedItems.isEmpty }.prefix(Self.maxRegions))
        for store in chosen {
            let condition = CLMonitor.CircularGeographicCondition(center: store.coordinate, radius: radiusMeters)
            // "assuming: .unsatisfied" = assume we start outside, so entering fires an event
            await monitor.add(condition, identifier: store.id, assuming: .unsatisfied)
            storeInfo[store.id] = (store.name, store.matchedItems.map(\.name))
        }
        watchedStoreNames = chosen.map(\.name)

        startListeningIfNeeded()
    }

    func stopAll() async {
        guard let monitor = clMonitor else { return }
        for identifier in await monitor.identifiers {
            await monitor.remove(identifier)
        }
        storeInfo.removeAll()
        watchedStoreNames = []
    }

    /// Waits for "entered region" events for as long as the app runs.
    private func startListeningIfNeeded() {
        guard eventsTask == nil, let monitor = clMonitor else { return }
        eventsTask = Task { [weak self] in
            do {
                for try await event in await monitor.events {
                    if event.state == .satisfied {
                        self?.handleEnter(storeId: event.identifier)
                    }
                }
            } catch {
                // The event stream ended - it is started again next time monitor(stores:) is called.
            }
            self?.eventsTask = nil
        }
    }

    private func handleEnter(storeId: String) {
        guard settings.storeAlerts,
              settings.shouldDeliver(isUrgent: false),
              let info = storeInfo[storeId] else { return }
        NotificationService.shared.sendStoreAlert(storeName: info.name, itemNames: info.items, storeId: storeId)
    }
}
