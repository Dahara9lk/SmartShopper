//
//  NotificationSettingsView.swift
//  SmartShopper
//
// notification preferences, and S19 when notifications are switched off in iOS.
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var testSent = false

    private let sensitivityOptions = [(200, "Low (200 m)"), (500, "Moderate (500 m)"), (1000, "High (1 km)"), (2500, "Wide (2.5 km)")]

    var body: some View {
        Group {
            if status == .denied || status == .notDetermined {
                NotificationsDeniedView(status: status) {
                    Task {
                        await NotificationService.shared.requestPermission()
                        await refreshStatus()
                    }
                }
            } else {
                settingsList
            }
        }
        .background(Color.canvas)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the iOS Settings app
            if phase == .active {
                Task { await refreshStatus() }
            }
        }
    }

    private func refreshStatus() async {
        status = await NotificationService.shared.authorizationStatus()
    }

    private var settingsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                InfoBanner(icon: "bell.badge.fill", title: "iOS notifications connected",
                           message: "Store, family and recap alerts are delivered as local notifications on this iPhone.")

                SettingsGroup(title: "Commute & Geofence Alerts") {
                    SettingsToggleRow(icon: "location.fill", title: "Along-Route Store Alerts",
                                      subtitle: "Heads-up when you are near a shop with items on your list",
                                      isOn: $settings.storeAlerts)
                    RowDivider()
                    HStack(spacing: 12) {
                        IconCircle(systemName: "scope", size: 34)
                        Text("Geofence Sensitivity")
                        Spacer()
                        Picker("Geofence Sensitivity", selection: $settings.alertRadiusMeters) {
                            ForEach(sensitivityOptions, id: \.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.brandPrimary)
                    }
                    .padding(14)
                }

                SettingsGroup(title: "Family Collaboration") {
                    SettingsToggleRow(icon: "text.badge.plus", title: "Items Added by Family",
                                      subtitle: "Instant alert when someone adds to the family list",
                                      isOn: $settings.familyItemAlerts)
                    RowDivider()
                    SettingsToggleRow(icon: "checkmark.circle.fill", title: "Items Purchased / Checked Off",
                                      subtitle: "Alert when a household member completes items",
                                      isOn: $settings.familyCheckedAlerts)
                    RowDivider()
                    SettingsToggleRow(icon: "doc.text.fill", iconColor: .textSecondary, title: "Trip Completed Summaries",
                                      subtitle: "Receipt summary after a trip is finished",
                                      isOn: $settings.tripSummaryAlerts)
                }

                SettingsGroup(title: "Recaps") {
                    SettingsToggleRow(icon: "chart.bar.fill", title: "Weekly Shopping Recap",
                                      subtitle: "Sunday evening reminder to review your list",
                                      isOn: $settings.weeklyRecap)
                        .onChange(of: settings.weeklyRecap) { _, isOn in
                            NotificationService.shared.scheduleWeeklyRecap(enabled: isOn)
                        }
                }

                SettingsGroup(title: "Schedule & Quiet Hours") {
                    SettingsToggleRow(icon: "moon.fill", iconColor: .infoBlue, title: "Quiet Hours",
                                      subtitle: "Mute grocery notifications during rest hours",
                                      isOn: $settings.quietHoursOn)
                    RowDivider()
                    HStack(spacing: 12) {
                        IconCircle(systemName: "clock.fill", color: .textSecondary, size: 34)
                        Text("Quiet Time Window")
                        Spacer()
                        Picker("From", selection: $settings.quietStartHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(SettingsStore.hourTitle(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        Text("–")
                        Picker("To", selection: $settings.quietEndHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(SettingsStore.hourTitle(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                    }
                    .pickerStyle(.menu)
                    .tint(.brandPrimary)
                    .padding(14)
                    .disabled(!settings.quietHoursOn)
                    RowDivider()
                    SettingsToggleRow(icon: "exclamationmark", iconColor: .warningOrange, title: "Urgent Items Override",
                                      subtitle: "Urgent family items can bypass Quiet Hours",
                                      isOn: $settings.urgentOverride)
                }

                SettingsGroup(title: "System & Diagnostics") {
                    SettingsValueRow(icon: "bell.fill", title: testSent ? "Test sent - check in 3 seconds" : "Send Test Commute Notification",
                                     titleColor: .brandPrimary, showChevron: false) {
                        NotificationService.shared.sendTestNotification()
                        testSent = true
                    }
                    RowDivider()
                    SettingsValueRow(icon: "gearshape.fill", iconColor: .textSecondary, title: "Open iOS System Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Text("SmartShopper uses Core Location geofencing to trigger alerts only when you are near relevant shops. Battery use is kept low by watching at most 10 shops.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}

// "Never Miss a Store Along Your Commute" - notifications are off.
struct NotificationsDeniedView: View {
    let status: UNAuthorizationStatus
    let onAllow: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(Color.dangerRed)
                        .frame(width: 40, height: 40)
                        .background(Color.dangerSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alerts Suspended")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dangerRed)
                        Text("Shops on your path have items from your list, but SmartShopper can't tell you.")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }
                .cardStyle()

                Text("Never Miss a Store Along Your Commute")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(status == .denied
                     ? "Notifications are turned off in iOS Settings. SmartShopper uses them to alert you when approaching a store that has your list items."
                     : "Allow notifications so SmartShopper can alert you when you approach a store that has your list items.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    alertRow(icon: "location.fill", title: "Commute Proximity Alerts", badge: "500 m",
                             text: "Reminder when you're near a shop with matched items.")
                    RowDivider()
                    alertRow(icon: "person.3.fill", title: "Family Member Sync Alerts", badge: "Real-time",
                             text: "Know when someone adds or checks off an item.")
                    RowDivider()
                    alertRow(icon: "chart.bar.fill", title: "Weekly Shopping Recap", badge: "Sunday",
                             text: "A short summary of your week's shopping.")
                }
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: AppLayout.cardRadius).stroke(Color.separatorLine))

                if status == .denied {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Enable in 3 quick taps", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        HStack(spacing: 8) {
                            stepBox(1, "Open", "iOS Settings")
                            stepBox(2, "Tap", "Notifications")
                            stepBox(3, "Switch ON", "Allow Alerts")
                        }
                    }
                    .cardStyle()

                    PrimaryButton(title: "Open iOS Settings", trailingArrow: true) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else {
                    PrimaryButton(title: "Allow Notifications", icon: "bell.fill", action: onAllow)
                }
                SecondaryButton(title: "Keep Notifications Off (Manual Only)",
                                background: .surfaceMuted, foreground: .textSecondary) {
                    dismiss()
                }
                Label("Item matching runs on-device. Your location and notifications are never shared with ad trackers.",
                      systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private func alertRow(icon: String, title: String, badge: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconCircle(systemName: icon, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Pill(text: badge, background: .brandMint)
                }
                Text(text).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private func stepBox(_ number: Int, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(number == 3 ? Color.brandMint : Color.surfaceMuted)
                .clipShape(Circle())
            Text(title).font(.caption.weight(.semibold))
            Text(subtitle).font(.caption2).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.surfaceMuted.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
