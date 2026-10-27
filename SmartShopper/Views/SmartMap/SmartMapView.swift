//
//  SmartMapView.swift
//  SmartShopper
//
//  Smart Map tab. A real MapKit map on top, and a panel underneath that changes with the state:
//    S27 results   - best matched shop card + other stores on route
//    S15 searching - "Matching Shops Along Route" progress
//    S17 no stores - expand radius / change route
//    S14 denied    - location permission needed
//  On iPad the panel sits beside the map instead of below it.
//

import SwiftUI
import MapKit

struct SmartMapView: View {
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var security: SecurityViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showRoute = false
    @State private var showDestinationSheet = false
    @State private var detailStore: NearbyStore?

    private var items: [ShoppingItem] { store.allRemainingItems }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    mapArea
                    ScrollView { panel.padding(AppLayout.screenPadding) }
                        .frame(width: 420)
                        .background(Color.canvas)
                }
            } else {
                VStack(spacing: 0) {
                    mapArea
                        .frame(height: 320)
                    ScrollView { panel.padding(AppLayout.screenPadding) }
                        .background(Color.canvas)
                }
            }
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(title: "Smart Map")
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $detailStore) { nearby in
            StoreDetailView(store: nearby)
        }
        .fullScreenCover(isPresented: $showRoute) {
            if let selected = smartMap.selectedStore {
                RouteView(store: selected)
            }
        }
        .sheet(isPresented: $showDestinationSheet) {
            DestinationSheet(items: items)
                .presentationDetents([.medium])
        }
        .task {
            smartMap.refreshPermissionState()
            if location.isAuthorized && smartMap.stores.isEmpty && smartMap.state != .searching {
                smartMap.refresh(items: items)
            }
        }
        .onChange(of: location.authorizationStatus) { _, _ in
            smartMap.refreshPermissionState()
            if location.isAuthorized {
                smartMap.refresh(items: items)
            }
        }
    }

    // MARK: Map

    private var mapArea: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $smartMap.cameraPosition) {
                UserAnnotation()

                ForEach(smartMap.stores) { nearby in
                    Annotation(nearby.name, coordinate: nearby.coordinate) {
                        Button {
                            Task { await smartMap.select(nearby) }
                        } label: {
                            StorePin(type: nearby.type, isSelected: smartMap.selectedStore?.id == nearby.id)
                        }
                        .accessibilityLabel("\(nearby.name), \(nearby.matchedItems.count) matched items")
                    }
                }

                if let route = smartMap.route {
                    MapPolyline(route)
                        .stroke(Color.infoBlue, lineWidth: 5)
                }

                if smartMap.state == .searching, let here = location.lastLocation {
                    MapCircle(center: here.coordinate, radius: smartMap.searchRadiusKm * 1000)
                        .foregroundStyle(Color.brandPrimary.opacity(0.10))
                        .stroke(Color.brandPrimary.opacity(0.4), lineWidth: 1)
                }
            }
            .mapStyle(smartMap.useSatellite ? .hybrid : .standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .opacity(smartMap.state == .denied ? 0.4 : 1)

            // Floating map buttons
            VStack(spacing: 10) {
                mapButton(icon: "location.fill", label: "Recenter") { smartMap.recenter() }
                mapButton(icon: smartMap.useSatellite ? "map.fill" : "square.3.layers.3d", label: "Map style") {
                    smartMap.useSatellite.toggle()
                }
                mapButton(icon: "arrow.clockwise", label: "Search again") { smartMap.refresh(items: items) }
            }
            .padding(12)
        }
    }

    private func mapButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .accessibilityLabel(label)
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        switch smartMap.state {
        case .needsPermission:
            LocationPermissionCard(isDenied: false)
        case .denied:
            LocationPermissionCard(isDenied: true)
        case .searching:
            searchingCard
        case .noResults:
            noResultsCard
        case .results:
            resultsPanel
        }
    }

    // MARK: S27 results

    @ViewBuilder
    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: AppLayout.sectionSpacing) {
            routeBar
            if let selected = smartMap.selectedStore {
                selectedStoreCard(selected)
            }
            if !smartMap.otherStores.isEmpty {
                HStack {
                    Text("Other Stores On Route")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(smartMap.otherStores.count) found")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(smartMap.otherStores) { other in
                            Button {
                                Task { await smartMap.select(other) }
                            } label: {
                                otherStoreCard(other)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !smartMap.unmatchedItems.isEmpty {
                availabilityAlert
            }
        }
    }

    private var routeBar: some View {
        Button {
            showDestinationSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(smartMap.destination == nil ? "Shops near you" : "Along your route")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    Text(smartMap.destination?.name ?? "Set a destination for detour times")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(Int(smartMap.searchRadiusKm)) km")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.separatorLine))
        }
        .buttonStyle(.plain)
    }

    private func selectedStoreCard(_ selected: NearbyStore) -> some View {
        let total = max(items.count, 1)
        let percent = Int((Double(selected.matchedItems.count) / Double(total) * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(selected.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityLabel("Best match")
                    }
                    Text(selected.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Pill(text: smartMap.detourText, color: .infoBlue, icon: "arrow.triangle.turn.up.right.diamond")
            }

            Label(selected.address.isEmpty ? "Address not available" : selected.address, systemImage: "location.fill")
                .font(.footnote)
                .foregroundStyle(Color.brandPrimary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: "sparkles").foregroundStyle(Color.brandPrimary)
                    Text("\(selected.matchedItems.count) items from your shopping list")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Pill(text: "\(percent)% match", background: .brandMint)
                }
                FlowLayout(spacing: 6) {
                    ForEach(selected.matchedItems.prefix(8)) { item in
                        Label(item.name, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.surface)
                            .clipShape(Capsule())
                    }
                }
                Label("Matched on-device with Core ML categories", systemImage: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                PrimaryButton(title: "Navigate", icon: "location.north.line.fill") {
                    Task {
                        if settings.quickAuthOnCommute {
                            guard await security.confirmIdentity(reason: "Confirm before starting your route") else { return }
                        }
                        showRoute = true
                    }
                }
                Button {
                    detailStore = selected
                } label: {
                    Label("Details", systemImage: "storefront")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(minWidth: 110, minHeight: AppLayout.buttonHeight)
                        .background(Color.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
                }
            }
        }
        .cardStyle()
    }

    private func otherStoreCard(_ other: NearbyStore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: other.type.icon).foregroundStyle(Color.brandPrimary)
                Text(other.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }
            Text(AppFormat.distance(other.distanceMeters))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            Text("\(other.matchedItems.count) match\(other.matchedItems.count == 1 ? "" : "es"): \(other.matchedItems.prefix(2).map(\.name).joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
        }
        .frame(width: 200, alignment: .leading)
        .cardStyle(padding: 12)
    }

    private var availabilityAlert: some View {
        HStack(alignment: .top, spacing: 12) {
            IconCircle(systemName: "exclamationmark.triangle.fill", color: .infoBlue, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text("ITEM AVAILABILITY ALERT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                Text("\(smartMap.unmatchedItems.count) item\(smartMap.unmatchedItems.count == 1 ? "" : "s") (\(smartMap.unmatchedItems.prefix(3).map(\.name).joined(separator: ", "))) may only be in stock at specialty stores further away.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(14)
        .background(Color.infoSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
    }

    // MARK: S15 searching

    private var searchingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                IconCircle(systemName: "scope", color: .infoBlue, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Matching Shops Along Route")
                        .font(.title3.weight(.semibold))
                    Text("Scanning shops within \(Int(smartMap.searchRadiusKm)) km for \(items.count) items on your list.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Matching categories & distances", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                    Spacer()
                    Text("\(Int(smartMap.searchProgress * 100))%")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
                ProgressBar(value: smartMap.searchProgress)
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach(smartMap.searchStatus.keys.sorted(), id: \.self) { key in
                let status = smartMap.searchStatus[key] ?? ""
                HStack(spacing: 12) {
                    Image(systemName: status == "Matched" ? "checkmark.circle.fill" : (status == "Scanning" ? "arrow.triangle.2.circlepath.circle.fill" : "clock.fill"))
                        .foregroundStyle(status == "Matched" ? Color.brandPrimary : Color.textSecondary)
                    Text(key).font(.subheadline.weight(.medium))
                    Spacer()
                    Pill(text: status, color: status == "Matched" ? .brandPrimary : .textSecondary)
                }
                .padding(12)
                .background(status == "Scanning" ? Color.brandMintSoft : Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Skeleton placeholders while loading
            HStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.surfaceMuted).frame(width: 90, height: 10)
                        RoundedRectangle(cornerRadius: 4).fill(Color.surfaceMuted).frame(height: 10)
                        RoundedRectangle(cornerRadius: 4).fill(Color.surfaceMuted).frame(width: 60, height: 10)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)

            SecondaryButton(title: "Cancel Scan & Browse Map Manually", icon: "xmark.circle",
                            background: .surfaceMuted, foreground: .textPrimary) {
                smartMap.cancelSearch()
            }
        }
        .cardStyle()
    }

    // MARK: S17 no results

    private var noResultsCard: some View {
        VStack(spacing: 16) {
            EmptyStateView(icon: "storefront",
                           title: "No Stores Found Along Route",
                           message: "We couldn't find shops matching your shopping list within \(Int(smartMap.searchRadiusKm)) km of your location.")
            Picker("Radius", selection: $smartMap.searchRadiusKm) {
                Text("5 km").tag(5.0)
                Text("10 km").tag(10.0)
                Text("15 km").tag(15.0)
                Text("25 km").tag(25.0)
            }
            .pickerStyle(.segmented)
            .onChange(of: smartMap.searchRadiusKm) { _, _ in
                smartMap.refresh(items: items)
            }
            if !items.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    IconCircle(systemName: "shippingbox.fill", color: .infoBlue, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ITEM AVAILABILITY ALERT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textSecondary)
                        Text("\(items.count) items (\(items.prefix(3).map(\.name).joined(separator: ", "))) are waiting for a matching shop.")
                            .font(.subheadline)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.infoSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            PrimaryButton(title: "Expand Search Radius to \(Int(min(25, smartMap.searchRadiusKm + 10))) km",
                          icon: "arrow.up.left.and.arrow.down.right") {
                smartMap.expandRadius(items: items)
            }
            SecondaryButton(title: "Change Route or Enter Custom Address", icon: "point.topleft.down.to.point.bottomright.curvepath",
                            background: .surfaceMuted, foreground: .textPrimary) {
                showDestinationSheet = true
            }
        }
        .cardStyle(padding: 20)
    }
}

/// Map pin: green circle with the shop type icon; bigger when selected.
struct StorePin: View {
    let type: StoreType
    let isSelected: Bool

    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: isSelected ? 18 : 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: isSelected ? 44 : 32, height: isSelected ? 44 : 32)
            .background(isSelected ? Color.brandPrimary : Color.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: isSelected ? 14 : 10))
            .overlay(RoundedRectangle(cornerRadius: isSelected ? 14 : 10).stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            .animation(.spring(response: 0.3), value: isSelected)
    }
}

/// S14 Location Services Needed (also used before permission is asked).
struct LocationPermissionCard: View {
    let isDenied: Bool
    @EnvironmentObject private var smartMap: SmartMapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Pill(text: isDenied ? "Access Required" : "Permission Needed",
                     color: .warningOrange, icon: "exclamationmark.triangle.fill")
                Spacer()
                Text(isDenied ? "Status: Denied in iOS Settings" : "Status: Not asked yet")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Text("Location Services Needed")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            Text("SmartShopper matches your list to shops on your device. Your coordinates are never sent to advertisers.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("UNAVAILABLE WITHOUT LOCATION")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("Privacy-First").font(.caption.weight(.semibold)).foregroundStyle(Color.brandPrimary)
                }
                featureRow("bell.badge.fill", "Live along-commute store alerts")
                featureRow("storefront.fill", "Nearby shop matching")
                featureRow("timer", "Automatic trip time savings")
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isDenied {
                PrimaryButton(title: "Open iOS Settings", icon: "arrow.up.forward.app") {
                    smartMap.openSettings()
                }
            } else {
                PrimaryButton(title: "Allow Location Access", icon: "location.fill") {
                    smartMap.askForPermission()
                }
            }
            Label("Your location is used only on this iPhone", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(Color.brandPrimary)
                .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Color.brandPrimary).frame(width: 22)
            Text(text).font(.subheadline)
            Spacer()
            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), unavailable")
    }
}

/// "Set Manual Route or City" sheet - enter home / work / a city.
struct DestinationSheet: View {
    let items: [ShoppingItem]
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Where are you heading? SmartShopper will show the extra minutes each shop adds to that trip.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                LabeledField(label: "Destination", icon: "mappin.and.ellipse", placeholder: "Home address, office or city",
                             text: $smartMap.destinationText)
                PrimaryButton(title: "Use This Route", icon: "point.topleft.down.to.point.bottomright.curvepath", isLoading: isSearching) {
                    Task {
                        isSearching = true
                        await smartMap.setDestination(items: items)
                        isSearching = false
                        dismiss()
                    }
                }
                if smartMap.destination != nil {
                    SecondaryButton(title: "Clear Route (shops near me)", icon: "xmark",
                                    background: .surfaceMuted, foreground: .textPrimary) {
                        smartMap.clearDestination(items: items)
                        dismiss()
                    }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Change Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
