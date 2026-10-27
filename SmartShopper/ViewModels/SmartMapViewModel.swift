//
//  SmartMapViewModel.swift
//  SmartShopper
//
//  ADVANCED FEATURE: MapKit + Core Location + Core ML working together.
//
//  1. Core ML has already given every list item a category.
//  2. We work out which shop types are needed (supermarket, pharmacy, ...).
//  3. MKLocalSearch finds REAL shops of those types near the user.
//  4. StoreMatcher ranks them by how many remaining items they cover + distance.
//  5. MKDirections draws the route and the detour time.
//  6. GeofenceService watches the best shops and sends an alert when you get close.
//

import Foundation
import Combine
import MapKit
import SwiftUI

@MainActor
final class SmartMapViewModel: ObservableObject {

    enum ScreenState: Equatable {
        case needsPermission      // first time - ask for location
        case denied               // S14 Location Services Needed
        case searching            // S15 Matching Shops Along Route
        case results              // S27 map + store card
        case noResults            // S17 No Stores Found Along Route
    }

    @Published private(set) var state: ScreenState = .needsPermission
    @Published private(set) var stores: [NearbyStore] = []
    @Published var selectedStore: NearbyStore?
    @Published private(set) var route: MKRoute?
    @Published private(set) var detourMinutes: Int?
    /// True when Apple Maps has no driving directions for this area (e.g. Sri Lanka).
    /// We then show a straight-line estimate instead of "Calculating..." forever.
    @Published private(set) var routeUnavailable = false
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: MapDefaults.colombo)
    @Published var searchRadiusKm: Double = 5
    @Published private(set) var searchProgress: Double = 0
    @Published private(set) var searchStatus: [String: String] = [:]   // store type title -> "Matched"/"Scanning"/"Queued"
    /// Optional "home / office" destination for along-route detours (Set Manual Route or City).
    @Published private(set) var destination: MKMapItem?
    @Published var destinationText = ""
    @Published private(set) var unmatchedItems: [ShoppingItem] = []
    @Published var useSatellite = false

    let location: LocationService
    let geofence: GeofenceService
    private let search = StoreSearchService()
    private let settings: SettingsStore
    private var searchTask: Task<Void, Never>?

    init(location: LocationService, geofence: GeofenceService, settings: SettingsStore) {
        self.location = location
        self.geofence = geofence
        self.settings = settings
    }

    /// The best shop - also shown on the Home "Shop Along Your Route" card.
    var topStore: NearbyStore? { stores.first }

    var otherStores: [NearbyStore] {
        guard let selectedStore else { return Array(stores.dropFirst()) }
        return stores.filter { $0.id != selectedStore.id }
    }

    // MARK: Permission

    func refreshPermissionState() {
        if location.isDenied {
            state = .denied
        } else if !location.isAuthorized {
            state = .needsPermission
        }
    }

    func askForPermission() {
        location.requestPermission()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Search

    /// Starts a new search for shops that match the remaining items.
    func refresh(items: [ShoppingItem]) {
        refreshPermissionState()
        guard location.isAuthorized else { return }
        searchTask?.cancel()
        searchTask = Task { await runSearch(items: items) }
    }

    func cancelSearch() {
        searchTask?.cancel()
        state = stores.isEmpty ? .noResults : .results
    }

    private func runSearch(items: [ShoppingItem]) async {
        state = .searching
        searchProgress = 0.1
        let types = StoreMatcher.neededStoreTypes(for: items)
        searchStatus = Dictionary(uniqueKeysWithValues: types.map { ($0.title, "Queued") })

        guard let here = await location.waitForLocation() else {
            state = .noResults
            return
        }
        let radius = searchRadiusKm * 1000
        var found: [NearbyStore] = []
        for (index, type) in types.enumerated() {
            if Task.isCancelled { return }
            searchStatus[type.title] = "Scanning"
            let results = await search.searchStores(near: here, radiusMeters: radius, types: [type])
            found += results
            searchStatus[type.title] = results.isEmpty ? "None nearby" : "Matched"
            searchProgress = 0.1 + 0.9 * Double(index + 1) / Double(types.count)
        }
        if Task.isCancelled { return }

        stores = StoreMatcher.rank(found, items: items, radiusMeters: radius)
        unmatchedItems = StoreMatcher.unmatchedItems(items, stores: stores)
        state = stores.isEmpty ? .noResults : .results

        if let best = stores.first {
            await select(best)
        }
        // Geofence alerts around the best shops
        if settings.alongRouteDetection {
            await geofence.monitor(stores: stores, radiusMeters: Double(settings.alertRadiusMeters))
        }
    }

    /// "Expand Search Radius to 15 mi"
    func expandRadius(items: [ShoppingItem]) {
        searchRadiusKm = min(25, searchRadiusKm + 10)
        refresh(items: items)
    }

    // MARK: Selecting a shop

    func select(_ store: NearbyStore) async {
        selectedStore = store
        route = nil
        detourMinutes = nil
        routeUnavailable = false
        guard let from = location.lastLocation?.coordinate, let mapItem = store.mapItem else { return }
        route = await search.route(from: from, to: mapItem)
        if route == nil {
            // No directions from Apple Maps: estimate the time from the distance (about 25 km/h in city traffic)
            routeUnavailable = true
            detourMinutes = max(1, Int((store.distanceMeters / 1000 / 25 * 60).rounded()))
        } else if let destination {
            detourMinutes = await search.detourMinutes(from: from, via: mapItem, to: destination)
        } else if let route {
            // No destination set: the "detour" is just the drive there
            detourMinutes = Int((route.expectedTravelTime / 60).rounded())
        }
        withAnimation {
            cameraPosition = .automatic
        }
    }

    // MARK: Manual route

    /// "Set Manual Route or City" / "Change Route or Enter Custom Address"
    func setDestination(items: [ShoppingItem]) async {
        let text = destinationText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            destination = nil
            return
        }
        destination = await search.findPlace(text, near: location.lastLocation)
        refresh(items: items)
    }

    func clearDestination(items: [ShoppingItem]) {
        destination = nil
        destinationText = ""
        refresh(items: items)
    }

    func recenter() {
        withAnimation {
            cameraPosition = .userLocation(fallback: MapDefaults.colombo)
        }
    }

    /// Opens Apple Maps with turn-by-turn directions to the shop.
    func openInMaps(_ store: NearbyStore) {
        store.mapItem?.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    /// "+3 min detour" text
    var detourText: String {
        guard let detourMinutes else { return "Calculating..." }
        if routeUnavailable { return "~\(detourMinutes) min (estimate)" }
        return destination == nil ? "\(detourMinutes) min drive" : "+\(detourMinutes) min detour"
    }
}

/// Where the map starts before the user's real location is known: Colombo, Sri Lanka.
enum MapDefaults {
    static let colombo = MapCameraPosition.region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
                           latitudinalMeters: 8_000, longitudinalMeters: 8_000))
}
