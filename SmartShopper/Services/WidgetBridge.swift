//
//  WidgetBridge.swift
//  SmartShopper
//
//  Created by Dahara on 2026-10-27.
//

import Foundation
import WidgetKit

enum WidgetBridge {

    /// Builds the list part of the snapshot (pure function, so it is unit tested).
    static func makeSnapshot(items: [ShoppingItem], keeping old: WidgetSnapshot) -> WidgetSnapshot {
        let remaining = items.filter { !$0.isPurchased }
        var snapshot = old
        snapshot.itemsLeft = remaining.count
        snapshot.nextItems = Array(remaining.prefix(3).map(\.name))
        snapshot.familyItemsLeft = remaining.filter(\.isFamily).count
        snapshot.totalText = AppFormat.money(remaining.reduce(0) { $0 + $1.lineTotal })
        if remaining.isEmpty {
            snapshot.bestShopName = nil
            snapshot.bestShopMatches = 0
        }
        snapshot.updatedAt = Date()
        return snapshot
    }

    /// Shopping list changed.
    static func updateList(items: [ShoppingItem]) {
        let snapshot = makeSnapshot(items: items, keeping: WidgetStorage.load())
        save(snapshot)
    }

    /// Smart Map finished a search.
    static func updateBestShop(_ store: NearbyStore?) {
        var snapshot = WidgetStorage.load()
        snapshot.bestShopName = store?.name
        snapshot.bestShopMatches = store?.matchedItems.count ?? 0
        snapshot.updatedAt = Date()
        save(snapshot)
    }

    private static func save(_ snapshot: WidgetSnapshot) {
        WidgetStorage.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()   // ask iOS to redraw the widget
    }
}
