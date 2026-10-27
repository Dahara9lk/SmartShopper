//
//  StoreSearchService.swift
//  SmartShopper
//
//  Finds REAL shops near the user with MapKit's MKLocalSearch,
//  and works out driving routes with MKDirections.
//

import Foundation
import MapKit

struct StoreSearchService {

    /// Searches every store type needed by the list and returns the shops inside the radius.
    func searchStores(near center: CLLocation, radiusMeters: Double, types: [StoreType]) async -> [NearbyStore] {
        var found: [NearbyStore] = []
        var seenIds = Set<String>()

        for type in types {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = type.searchQuery
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(center: center.coordinate,
                                                latitudinalMeters: radiusMeters * 2,
                                                longitudinalMeters: radiusMeters * 2)
            guard let response = try? await MKLocalSearch(request: request).start() else { continue }

            for mapItem in response.mapItems {
                let coordinate = mapItem.placemark.coordinate
                let place = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = place.distance(from: center)
                let name = mapItem.name ?? type.title
                // id from name + rounded position, so the same shop found twice is kept once
                let id = "\(name)-\(Int(coordinate.latitude * 10_000))-\(Int(coordinate.longitude * 10_000))"
                guard distance <= radiusMeters, !seenIds.contains(id) else { continue }
                seenIds.insert(id)
                found.append(NearbyStore(id: id,
                                         name: name,
                                         type: type,
                                         coordinate: coordinate,
                                         address: mapItem.placemark.title ?? "",
                                         phone: mapItem.phoneNumber,
                                         distanceMeters: distance,
                                         mapItem: mapItem))
            }
        }
        return found
    }

    /// Driving route from the user to a shop.
    func route(from start: CLLocationCoordinate2D, to destination: MKMapItem) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = destination
        request.transportType = .automobile
        let response = try? await MKDirections(request: request).calculate()
        return response?.routes.first
    }

    /// Extra minutes a shop adds to a trip home: (you -> shop -> home) minus (you -> home).
    func detourMinutes(from start: CLLocationCoordinate2D, via store: MKMapItem, to destination: MKMapItem) async -> Int? {
        guard let direct = await route(from: start, to: destination),
              let toStore = await route(from: start, to: store) else { return nil }
        let storeRequest = MKDirections.Request()
        storeRequest.source = store
        storeRequest.destination = destination
        storeRequest.transportType = .automobile
        guard let fromStore = try? await MKDirections(request: storeRequest).calculate().routes.first else { return nil }
        let extra = toStore.expectedTravelTime + fromStore.expectedTravelTime - direct.expectedTravelTime
        return max(0, Int((extra / 60).rounded()))
    }

    /// Looks up a place the user typed (home, office, city) for "Set Manual Route".
    func findPlace(_ text: String, near center: CLLocation?) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        if let center {
            request.region = MKCoordinateRegion(center: center.coordinate,
                                                latitudinalMeters: 50_000,
                                                longitudinalMeters: 50_000)
        }
        return try? await MKLocalSearch(request: request).start().mapItems.first
    }
}
