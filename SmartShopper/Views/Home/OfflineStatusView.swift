//
//  OfflineStatusView.swift
//  SmartShopper
//
//  Figma S21 - shown on Home when there is no internet (or changes are waiting to upload).
//  Firestore keeps working offline: edits are queued and synced when back online.
//

import SwiftUI

struct OfflineStatusView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Banner
            HStack(alignment: .top, spacing: 12) {
                IconCircle(systemName: network.isConnected ? "arrow.triangle.2.circlepath" : "wifi.slash",
                           color: .warningOrange, size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(network.isConnected ? "Syncing your changes" : "You're offline")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Text("You can still check off items and view cached aisle routes. Changes will automatically sync with your Family Circle once back online.")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            // Pending sync row
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(store.pendingSyncCount) item\(store.pendingSyncCount == 1 ? "" : "s") pending cloud sync")
                        .font(.subheadline.weight(.medium))
                    Text(network.isConnected ? "Uploading now" : "Awaiting network handshake")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Button {
                    network.testConnection()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.onPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Engine availability
            Text("Engine Availability")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            engineRow(icon: "square.and.pencil", title: "On-device item editing",
                      subtitle: "Full local write access", status: "Available", color: .brandPrimary)
            engineRow(icon: "brain", title: "Core ML item matching",
                      subtitle: "Runs fully on this iPhone", status: "Available", color: .brandPrimary)
            engineRow(icon: "map.fill", title: "Store search (MapKit)",
                      subtitle: "Needs cellular or Wi-Fi", status: network.isConnected ? "Live" : "Paused",
                      color: network.isConnected ? .brandPrimary : .infoBlue)
            engineRow(icon: "person.2.fill", title: "Family live updates",
                      subtitle: "Changes will push on reconnect", status: network.isConnected ? "Live" : "Queued",
                      color: network.isConnected ? .brandPrimary : .infoBlue)

            // Diagnostic
            HStack {
                VStack(spacing: 2) {
                    Text("Cached Items").font(.caption).foregroundStyle(Color.textSecondary)
                    Text("\(store.items.count)").font(.title3.weight(.semibold)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text("Pending Mutations").font(.caption).foregroundStyle(Color.textSecondary)
                    Text("\(store.pendingSyncCount)").font(.title3.weight(.semibold)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            PrimaryButton(title: "Tap to Test Connection", icon: "antenna.radiowaves.left.and.right") {
                network.testConnection()
            }
        }
        .cardStyle()
    }

    private func engineRow(icon: String, title: String, subtitle: String, status: String, color: Color) -> some View {
        HStack(spacing: 12) {
            IconCircle(systemName: icon, color: .textSecondary, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Pill(text: status, color: color)
        }
        .accessibilityElement(children: .combine)
    }
}
