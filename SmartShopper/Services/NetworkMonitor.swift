//
//  NetworkMonitor.swift
//  SmartShopper
//
//  Watches the internet connection (Network framework) so the Home screen
//  can show the offline state (Figma S21).
//

import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {

    @Published private(set) var isConnected = true
    @Published private(set) var lastChecked = Date()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isConnected = online
                self?.lastChecked = Date()
            }
        }
        monitor.start(queue: queue)
    }

    /// "Tap to Test Connection" button - reads the current path again.
    func testConnection() {
        isConnected = monitor.currentPath.status == .satisfied
        lastChecked = Date()
    }
}
