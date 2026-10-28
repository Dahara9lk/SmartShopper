//
//  NearbyStore.swift
//  SmartShopper

import Foundation
import MapKit

struct NearbyStore: Identifiable, Hashable {
    let id: String
    let name: String
    let type: StoreType
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phone: String?
 
    let distanceMeters: Double

    let mapItem: MKMapItem?

    var matchedItems: [ShoppingItem] = []
    
    var matchScore: Double = 0

    static func == (lhs: NearbyStore, rhs: NearbyStore) -> Bool {
        lhs.id == rhs.id && lhs.matchedItems == rhs.matchedItems && lhs.matchScore == rhs.matchScore
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var subtitle: String {
        "\(type.title) • \(AppFormat.distance(distanceMeters))"
    }
}
