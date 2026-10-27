//
//  StoreDetailView.swift
//  SmartShopper
//
//  Figma S25: one shop - header, contact, "SmartMatch In-Store" list with Mark Picked,
//  items it doesn't have ("Remaining On Route"), mini map, Start Route Navigation.
//

import SwiftUI
import MapKit

struct StoreDetailView: View {
    let store: NearbyStore

    @EnvironmentObject private var data: AppDataStore
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @Environment(\.openURL) private var openURL
    @State private var showRoute = false
    @AppStorage("savedStores") private var savedStoresText = ""

    /// Live copy of the matched items (so "Mark Picked" updates straight away).
    private var matched: [ShoppingItem] {
        let ids = Set(store.matchedItems.map(\.id))
        return data.items.filter { ids.contains($0.id) }
    }

    private var notHere: [ShoppingItem] {
        let ids = Set(store.matchedItems.map(\.id))
        return data.allRemainingItems.filter { !ids.contains($0.id) }
    }

    private var isSaved: Bool { savedStoresText.split(separator: "|").map(String.init).contains(store.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.sectionSpacing) {
                header
                infoRow
                matchCard
                if !notHere.isEmpty { remainingCard }
                locationCard
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle("Store Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: "\(store.name) - \(store.address)") {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .fullScreenCover(isPresented: $showRoute) {
            RouteView(store: store)
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: store.type.icon)
                    .font(.title)
                Spacer()
                Pill(text: "\(AppFormat.distance(store.distanceMeters)) away", color: .white, background: Color.white.opacity(0.2))
            }
            Spacer(minLength: 20)
            Text(store.name)
                .font(.title.weight(.bold))
            Label(store.address.isEmpty ? store.type.title : store.address, systemImage: "mappin.circle.fill")
                .font(.subheadline)
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.heroGreen, Color.brandAccent], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var infoRow: some View {
        HStack(spacing: 10) {
            infoTile(icon: "tag.fill", title: "Store type", value: store.type.title)
            infoTile(icon: "phone.fill", title: "Phone", value: store.phone ?? "Not listed")
        }
    }

    private func infoTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            IconCircle(systemName: icon, color: .infoBlue, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(Color.textSecondary)
                Text(value).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private var matchCard: some View {
        let picked = matched.filter(\.isPurchased).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconCircle(systemName: "sparkles", size: 34, filled: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SmartMatch In-Store").font(.headline)
                    Text("List items this shop can supply").font(.caption).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Pill(text: "\(picked)/\(matched.count) picked", background: .brandMint)
            }
            ProgressBar(value: matched.isEmpty ? 0 : Double(picked) / Double(matched.count), height: 5)
            ForEach(matched) { item in
                HStack(spacing: 12) {
                    CheckBox(isChecked: item.isPurchased)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.titleWithQuantity)
                            .font(.subheadline.weight(.medium))
                            .strikethrough(item.isPurchased)
                        Text("\(item.category.aisleText) • \(AppFormat.money(item.lineTotal))")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Button(item.isPurchased ? "Undo" : "Mark Picked") {
                        data.togglePurchased(item)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandMintSoft)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }

    private var remainingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Remaining On Route (\(notHere.count))", systemImage: "arrow.triangle.branch")
                    .font(.headline)
                Spacer()
                Text("Not at this shop").font(.caption).foregroundStyle(Color.textSecondary)
            }
            ForEach(notHere.prefix(6)) { item in
                HStack(spacing: 12) {
                    IconCircle(systemName: item.category.icon, color: item.category.color, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(.subheadline.weight(.medium))
                        Text("Try a \(item.category.storeTypes.first?.title.lowercased() ?? "shop")")
                            .font(.caption)
                            .foregroundStyle(Color.dangerRed)
                    }
                    Spacer()
                    Pill(text: "Check Next", color: .textSecondary, background: .surfaceMuted)
                }
            }
        }
        .cardStyle()
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STORE LOCATION").font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                Spacer()
                Button("Open in Maps") { smartMap.openInMaps(store) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            Map(initialPosition: .region(MKCoordinateRegion(center: store.coordinate,
                                                            latitudinalMeters: 800,
                                                            longitudinalMeters: 800))) {
                Marker(store.name, systemImage: store.type.icon, coordinate: store.coordinate)
                    .tint(Color.brandPrimary)
                UserAnnotation()
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .allowsHitTesting(false)
            .accessibilityLabel("Map showing \(store.name)")
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                if let phone = store.phone,
                   let url = URL(string: "tel://" + phone.filter { $0.isNumber || $0 == "+" }) {
                    openURL(url)
                }
            } label: {
                Image(systemName: "phone.fill")
                    .frame(width: 52, height: 52)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(store.phone == nil)
            .accessibilityLabel("Call store")

            Button {
                toggleSaved()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .frame(width: 52, height: 52)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Bookmark store")

            PrimaryButton(title: "Start Route Navigation", icon: "location.north.line.fill") {
                Task {
                    await smartMap.select(store)
                    showRoute = true
                }
            }
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func toggleSaved() {
        var saved = savedStoresText.split(separator: "|").map(String.init)
        if saved.contains(store.id) {
            saved.removeAll { $0 == store.id }
        } else {
            saved.append(store.id)
        }
        savedStoresText = saved.joined(separator: "|")
    }
}
