//
//  NearbyStore.swift
//  SmartShopper
//
//  A real shop found with MapKit (MKLocalSearch) plus the list items it can supply.
//

import Foundation
import MapKit

struct NearbyStore: Identifiable, Hashable {
    let id: String
    let name: String
    let type: StoreType
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phone: String?
    /// Straight-line distance from the user in metres.
    let distanceMeters: Double
    /// The MapKit item - needed for directions and "Open in Maps". Optional so tests can skip it.
    let mapItem: MKMapItem?

    /// Remaining list items this shop can supply (filled by StoreMatcher).
    var matchedItems: [ShoppingItem] = []
    /// 0...1 ranking score (filled by StoreMatcher).
    var matchScore: Double = 0

    static func == (lhs: NearbyStore, rhs: NearbyStore) -> Bool {
        lhs.id == rhs.id && lhs.matchedItems == rhs.matchedItems && lhs.matchScore == rhs.matchScore
    }

    /// Hashable by id only (needed for navigationDestination).
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Short "Supermarket • 350 m"
    var subtitle: String {
        "\(type.title) • \(AppFormat.distance(distanceMeters))"
    }
}
