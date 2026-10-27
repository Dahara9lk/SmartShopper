//
//  HomeView.swift
//  SmartShopper
//
//  Figma S11 Home dashboard:
//   greeting, green "Shop Along Your Route" card (best matched shop from Smart Map),
//   4 quick actions, active list progress, family activity feed, tip card.
//  When offline, the S21 offline panel is shown at the top.
//  On iPad the cards are laid out in two columns.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var location: LocationService
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showAddItem = false
    @State private var showRoute = false
    @State private var storeForDetail: NearbyStore?

    private var myItems: [ShoppingItem] { store.myItems }
    private var remaining: [ShoppingItem] { myItems.filter { !$0.isPurchased } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.sectionSpacing) {
                if !network.isConnected || store.pendingSyncCount > 0 {
                    OfflineStatusView()
                }

                greeting

                if sizeClass == .regular {
                    // iPad: two columns
                    HStack(alignment: .top, spacing: AppLayout.sectionSpacing) {
                        VStack(spacing: AppLayout.sectionSpacing) {
                            heroCard
                            quickActions
                            tipCard
                        }
                        VStack(spacing: AppLayout.sectionSpacing) {
                            activeListCard
                            familyActivityCard
                        }
                    }
                } else {
                    heroCard
                    quickActions
                    activeListCard
                    familyActivityCard
                    tipCard
                }
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(title: "Home")
        }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            smartMap.refresh(items: store.allRemainingItems)
        }
        .sheet(isPresented: $showAddItem) {
            ItemEditorView()
        }
        .fullScreenCover(isPresented: $showRoute) {
            if let store = smartMap.selectedStore {
                RouteView(store: store)
            }
        }
        .navigationDestination(item: $storeForDetail) { nearby in
            StoreDetailView(store: nearby)
        }
        .onChange(of: router.showAddItemSheet) { _, show in
            if show {
                showAddItem = true
                router.showAddItemSheet = false
            }
        }
        .task {
            // Find shops for the Home hero card the first time
            if smartMap.stores.isEmpty && location.isAuthorized {
                smartMap.refresh(items: store.allRemainingItems)
            }
        }
    }

    // MARK: Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HomeHelper.greeting(hour: Calendar.current.component(.hour, from: Date())) + ",")
                .font(.title2)
                .foregroundStyle(Color.textSecondary)
            Text(store.profile?.firstName ?? "Shopper")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .padding(.top, 4)
    }

    // MARK: Hero card

    @ViewBuilder
    private var heroCard: some View {
        if let top = smartMap.topStore {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Shop Along Your Route", systemImage: "circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                    Spacer()
                    Label("\(AppFormat.distance(top.distanceMeters)) ahead", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                }
                Text(top.name)
                    .font(.title2.weight(.bold))
                Text("\(top.type.title) • items from your list available here")
                    .font(.subheadline)
                    .opacity(0.85)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(top.matchedItems.count) ITEMS ON YOUR LIST")
                            .font(.caption.weight(.bold))
                            .opacity(0.85)
                        Text(top.matchedItems.prefix(4).map(\.name).joined(separator: ", "))
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await smartMap.select(top)
                            showRoute = true
                        }
                    } label: {
                        Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.heroGreen)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button {
                        storeForDetail = top
                    } label: {
                        Label("View Match", systemImage: "list.bullet.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                LinearGradient(colors: [Color.heroGreen, Color.heroGreen.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            // No shop found yet - invite the user to open Smart Map
            VStack(alignment: .leading, spacing: 10) {
                Label("Shop Along Your Route", systemImage: "location.viewfinder")
                    .font(.caption.weight(.semibold))
                Text(remaining.isEmpty ? "Add items to get shop matches" : "Find shops for your \(remaining.count) items")
                    .font(.title3.weight(.bold))
                Text("Smart Map uses on-device AI to match your list with real shops near you.")
                    .font(.subheadline)
                    .opacity(0.85)
                Button {
                    router.open(.smartMap)
                } label: {
                    Label("Open Smart Map", systemImage: "safari.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.heroGreen)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.heroGreen)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction(icon: "plus", title: "Add Item") { showAddItem = true }
            quickAction(icon: "checklist", title: "My Lists") {
                router.openFamilyList = false
                router.open(.lists)
            }
            quickAction(icon: "person.2.fill", title: "Family") {
                router.openFamilyList = true
                router.open(.lists)
            }
            quickAction(icon: "storefront.fill", title: "Find Shops") { router.open(.smartMap) }
        }
    }

    private func quickAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.brandMintSoft)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.separatorLine, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Active list

    private var activeListCard: some View {
        let progress = ListsViewModel.progress(myItems)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE SHOPPING LIST")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                    Text("My Shopping List")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
                ProgressRing(value: progress)
            }
            HStack {
                Text("\(remaining.count) of \(myItems.count) items remaining")
                Spacer()
                Text("\(myItems.count - remaining.count) checked")
            }
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)

            ProgressBar(value: progress)

            if !remaining.isEmpty {
                Text("REMAINING TO PICK")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                FlowLayout(spacing: 8) {
                    ForEach(remaining.prefix(8)) { item in
                        ItemChip(title: item.name)
                    }
                }
            } else {
                Button {
                    showAddItem = true
                } label: {
                    Label("Add your first item", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                }
            }
        }
        .cardStyle()
        .onTapGesture { router.open(.lists) }
    }

    // MARK: Family activity

    private var familyActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AvatarStack(names: store.members.map(\.name))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Family Activity")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Label(store.isDemoMode ? "Saved on this device" : "Synced via Firebase",
                          systemImage: "checkmark.icloud.fill")
                        .font(.caption)
                        .foregroundStyle(Color.brandPrimary)
                }
                Spacer()
                Button {
                    router.showActivitySheet = true
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.surfaceMuted)
                        .clipShape(Circle())
                }
                .accessibilityLabel("See all activity")
            }

            if store.activity.isEmpty {
                Text("No family activity yet. Invite family from the Lists tab.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(store.activity.prefix(3)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.kind == .checked ? "checkmark.circle.fill" : "cart.badge.plus")
                            .foregroundStyle(Color.brandPrimary)
                        Text(event.text)
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(AppFormat.timeAgo(event.date))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(10)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }

    // MARK: Tip

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Color.infoBlue)
                .frame(width: 36, height: 36)
                .background(Color.surface)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("TIP FOR TODAY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.infoBlue)
                Text(HomeHelper.tip(items: store.allRemainingItems, topStore: smartMap.topStore))
                    .font(.subheadline)
                    .foregroundStyle(Color.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.infoSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
        .accessibilityElement(children: .combine)
    }
}
