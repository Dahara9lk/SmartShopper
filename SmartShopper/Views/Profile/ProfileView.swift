//
//  ProfileView.swift
//  SmartShopper
//
//  Profile / Settings: security, appearance (light / dark mode),
//  location & alert radius, family circle, notifications, preferences, sign out.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var security: SecurityViewModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var geofence: GeofenceService
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @EnvironmentObject private var network: NetworkMonitor

    @State private var showSignOutConfirm = false
    @State private var showInvite = false
    @State private var cacheCleared = false

    private let radiusOptions = [200, 500, 1000, 2500]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                profileCard
                securityGroup
                appearanceGroup
                locationGroup
                familyGroup
                notificationsGroup
                preferencesGroup

                Button {
                    showSignOutConfirm = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .foregroundStyle(Color.dangerRed)
                        .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
                        .overlay(RoundedRectangle(cornerRadius: AppLayout.cardRadius).stroke(Color.separatorLine))
                }

                VStack(spacing: 2) {
                    Text("SmartShopper for iOS v1.0 • \(store.isDemoMode ? "Demo mode (local data)" : "Firebase connected")")
                    Text("Privacy-First Architecture • On-device Core ML")
                }
                .font(.caption2)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(title: "Profile")
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Sign out of SmartShopper?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await geofence.stopAll() }
                store.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet().presentationDetents([.medium, .large])
        }
    }

    // Profile card

    private var profileCard: some View {
        HStack(spacing: 14) {
            AvatarCircle(name: store.userName, size: 56, showOnline: network.isConnected)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.userName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Text(store.profile?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Label(store.household?.name ?? "No family circle", systemImage: "house.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandPrimary)
            }
            Spacer()
        }
        .cardStyle()
        .padding(.top, 4)
    }

    // Security

    private var securityGroup: some View {
        SettingsGroup(title: "Security & Access") {
            SettingsToggleRow(icon: "faceid", title: "\(security.biometryName) Unlock",
                              subtitle: "Require \(security.biometryName) when opening the app",
                              isOn: Binding(get: { settings.faceIDEnabled },
                                            set: { newValue in Task { await security.setFaceIDEnabled(newValue) } }))
            RowDivider()
            Menu {
                ForEach([0, 60, 300], id: \.self) { seconds in
                    Button(SettingsStore.lockTimeoutTitle(seconds)) { settings.lockTimeoutSeconds = seconds }
                }
            } label: {
                SettingsValueRow(icon: "123.rectangle.fill", iconColor: .infoBlue, title: "Require Passcode",
                                 value: SettingsStore.lockTimeoutTitle(settings.lockTimeoutSeconds), showChevron: true)
            }
            RowDivider()
            NavigationLink {
                BiometricSettingsView()
            } label: {
                SettingsValueRow(icon: "lock.shield.fill", title: "Biometric Protection",
                                 subtitle: "Family lists, commute & passcode", showChevron: true)
            }
            RowDivider()
            SettingsValueRow(icon: "key.fill", iconColor: .textSecondary, title: "Encrypted Keychain",
                             subtitle: "Passcode & saved sign-in stay on this device",
                             value: PasscodeStore.hasPasscode ? "Active" : "Not set",
                             valueColor: PasscodeStore.hasPasscode ? .brandPrimary : .textSecondary,
                             showChevron: false)
        }
    }

    // Appearance (dark mode)

    private var appearanceGroup: some View {
        SettingsGroup(title: "Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconCircle(systemName: "circle.lefthalf.filled", color: .infoBlue, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme").font(.body)
                        Text("Light, Dark or follow your iPhone setting")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(14)
        }
    }

    // Location

    private var locationGroup: some View {
        SettingsGroup(title: "Location & Smart Route Matching", trailing: location.isAuthorized ? "Live" : nil) {
            SettingsValueRow(icon: "location.fill", title: "Location Access",
                             subtitle: location.isPreciseLocation ? "Precise location on" : "Precise location off",
                             value: location.statusText,
                             valueColor: location.isAuthorized ? .brandPrimary : .dangerRed) {
                if location.authorizationStatus == .notDetermined {
                    location.requestPermission()
                } else if location.authorizationStatus == .authorizedWhenInUse {
                    location.requestAlwaysPermission()
                } else {
                    smartMap.openSettings()
                }
            }
            RowDivider()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconCircle(systemName: "scope", size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shop Alert Radius").font(.body)
                        Text("Notify when a matched shop is this close")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text(AppFormat.distance(Double(settings.alertRadiusMeters)))
                        .font(.headline)
                        .foregroundStyle(Color.brandPrimary)
                }
                Picker("Radius", selection: $settings.alertRadiusMeters) {
                    ForEach(radiusOptions, id: \.self) { meters in
                        Text(AppFormat.distance(Double(meters))).tag(meters)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.alertRadiusMeters) { _, newValue in
                    Task { await geofence.monitor(stores: smartMap.stores, radiusMeters: Double(newValue)) }
                }
            }
            .padding(14)
            RowDivider()
            SettingsToggleRow(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                              title: "Along-Route Detection",
                              subtitle: geofence.watchedStoreNames.isEmpty
                                ? "Watches your best matched shops for alerts"
                                : "Watching \(geofence.watchedStoreNames.count) shops: \(geofence.watchedStoreNames.prefix(2).joined(separator: ", "))",
                              isOn: $settings.alongRouteDetection)
                .onChange(of: settings.alongRouteDetection) { _, isOn in
                    Task {
                        if isOn {
                            await geofence.monitor(stores: smartMap.stores, radiusMeters: Double(settings.alertRadiusMeters))
                        } else {
                            await geofence.stopAll()
                        }
                    }
                }
        }
    }

    // Family

    private var familyGroup: some View {
        SettingsGroup(title: "Family & Collaboration") {
            SettingsValueRow(icon: "person.3.fill", iconColor: .infoBlue,
                             title: store.household?.name ?? "Family Circle",
                             subtitle: store.members.map { $0.id == store.profile?.id ? "You" : $0.name }.joined(separator: ", "),
                             value: "\(store.members.count) Member\(store.members.count == 1 ? "" : "s")",
                             showChevron: false)
            RowDivider()
            SettingsValueRow(icon: "arrow.triangle.2.circlepath.icloud.fill", iconColor: .textSecondary,
                             title: "Cloud Sync Status",
                             subtitle: store.isDemoMode ? "Demo mode - data stays on this device" : "Real-time sync with Firebase",
                             value: network.isConnected ? (store.pendingSyncCount > 0 ? "\(store.pendingSyncCount) pending" : "Up to date") : "Offline",
                             valueColor: network.isConnected ? .brandPrimary : .warningOrange,
                             showChevron: false)
            RowDivider()
            SettingsValueRow(icon: "person.text.rectangle.fill", iconColor: .textSecondary, title: "Member Role",
                             value: store.members.first { $0.id == store.profile?.id }?.role ?? "Member",
                             showChevron: false)
            RowDivider()
            SettingsValueRow(icon: "qrcode", iconColor: .textSecondary, title: "Invite Code",
                             value: store.household?.inviteCode ?? "-", valueColor: .brandPrimary, showChevron: false)
            RowDivider()
            SettingsValueRow(icon: "person.badge.plus", title: "+ Invite New Family Member",
                             titleColor: .brandPrimary, showChevron: false) {
                showInvite = true
            }
        }
    }

    // Notifications

    private var notificationsGroup: some View {
        SettingsGroup(title: "Notifications") {
            SettingsToggleRow(icon: "bag.fill", iconColor: .textSecondary, title: "Stock Match Alerts",
                              subtitle: "When matched shops are nearby", isOn: $settings.storeAlerts)
            RowDivider()
            SettingsToggleRow(icon: "text.badge.plus", iconColor: .textSecondary, title: "Family Item Added",
                              subtitle: "When someone adds to the family list", isOn: $settings.familyItemAlerts)
            RowDivider()
            SettingsToggleRow(icon: "chart.bar.fill", iconColor: .textSecondary, title: "Weekly Savings Summary",
                              subtitle: "Sunday evening recap", isOn: $settings.weeklyRecap)
                .onChange(of: settings.weeklyRecap) { _, isOn in
                    NotificationService.shared.scheduleWeeklyRecap(enabled: isOn)
                }
            RowDivider()
            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsValueRow(icon: "bell.badge.fill", title: "All Notification Settings",
                                 subtitle: "Quiet hours, test alert, family alerts", showChevron: true)
            }
        }
    }

    // Preferences

    private var preferencesGroup: some View {
        SettingsGroup(title: "Preferences") {
            SettingsValueRow(icon: "ruler.fill", iconColor: .textSecondary, title: "Default Unit",
                             value: settings.useMetric ? "Metric (kg, L)" : "Imperial (lb, gal)") {
                settings.useMetric.toggle()
            }
            RowDivider()
            SettingsValueRow(icon: "arrow.counterclockwise", iconColor: .textSecondary, title: "Clear Completed Items",
                             subtitle: "Removes purchased items from your lists",
                             value: cacheCleared ? "Cleared" : "\(store.items.filter(\.isPurchased).count) items") {
                store.clearCompleted(family: false)
                store.clearCompleted(family: true)
                cacheCleared = true
            }
            RowDivider()
            SettingsValueRow(icon: "cpu", iconColor: .textSecondary, title: "On-Device Item Classifier",
                             subtitle: "Core ML model for shop categories",
                             value: ItemClassifierService.shared.isModelLoaded ? "Loaded" : "Missing",
                             valueColor: ItemClassifierService.shared.isModelLoaded ? .brandPrimary : .dangerRed,
                             showChevron: false)
        }
    }
}
