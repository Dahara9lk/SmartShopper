//
//  ListsView.swift
//  SmartShopper
//
//  Lists tab. A "My List | Family" switch at the top.
//   My List  -> Figma S3 (items, filter chips, progress, purchased, Start Shopping Mode)
//               or S6 (empty state with popular staples)
//   Family   -> FamilyListView (S10 / S16)
//

import SwiftUI

struct ListsView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var smartMap: SmartMapViewModel
    @StateObject private var viewModel = ListsViewModel()

    private var items: [ShoppingItem] { store.myItems }
    private var filtered: [ShoppingItem] { ListsViewModel.filter(items, by: viewModel.selectedCategory) }
    private var remaining: [ShoppingItem] { filtered.filter { !$0.isPurchased } }
    private var purchased: [ShoppingItem] { filtered.filter { $0.isPurchased } }

    var body: some View {
        VStack(spacing: 0) {
            CapsuleSegment(options: ["My List", "Family"],
                           selection: Binding(get: { viewModel.mode.rawValue },
                                              set: { viewModel.mode = ListsViewModel.Mode(rawValue: $0) ?? .myList }))
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 8)

            if viewModel.mode == .family {
                FamilyListView(viewModel: viewModel)
            } else if items.isEmpty {
                EmptyListView(viewModel: viewModel)
            } else {
                myList
            }
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(title: "Lists")
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.showAddItem) {
            ItemEditorView(startInFamily: viewModel.mode == .family)
        }
        .sheet(item: $viewModel.itemToEdit) { item in
            ItemEditorView(item: item)
        }
        .fullScreenCover(isPresented: $viewModel.showInStoreMode) {
            InStoreModeView(items: viewModel.mode == .family ? store.familyItems : store.myItems,
                            storeName: smartMap.selectedStore?.name ?? "Your Store",
                            storeArea: smartMap.selectedStore?.address ?? "")
        }
        .onAppear(perform: applyRouterRequest)
        .onChange(of: router.openFamilyList) { _, _ in applyRouterRequest() }
    }

    /// Home's "Family" quick action opens the Family list.
    private func applyRouterRequest() {
        if router.openFamilyList {
            viewModel.mode = .family
            router.openFamilyList = false
        }
    }

    // MARK: S3 My List

    private var myList: some View {
        List {
            // Filter chips + progress card
            Section {
                VStack(spacing: 14) {
                    categoryChips
                    progressCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    viewModel.showAddItem = true
                } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.brandPrimary)
                }
                .listRowBackground(Color.surface)

                ForEach(remaining) { item in
                    ItemRow(item: item, subtitle: item.category.aisleText) {
                        store.togglePurchased(item)
                    }
                    .listRowBackground(Color.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.delete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            viewModel.itemToEdit = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.infoBlue)
                    }
                }
            } header: {
                SectionHeader(title: "Remaining Items (\(remaining.count))", actionTitle: "Swipe left for actions")
            }

            if !purchased.isEmpty {
                Section {
                    ForEach(purchased) { item in
                        ItemRow(item: item, subtitle: item.category.aisleText) {
                            store.togglePurchased(item)
                        }
                        .listRowBackground(Color.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Purchased Items (\(purchased.count))", actionTitle: "Clear Completed") {
                        withAnimation { store.clearCompleted(family: false) }
                    }
                }
            }

            Section {
                PrimaryButton(title: "Start Shopping Mode", icon: "location.north.circle.fill",
                              isEnabled: !store.myItems.filter { !$0.isPurchased }.isEmpty) {
                    viewModel.showInStoreMode = true
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .headerProminence(.standard)
        .environment(\.defaultMinListRowHeight, 52)
        .animation(.default, value: items)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All (\(items.count))", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }
                ForEach(ListsViewModel.categoryCounts(items), id: \.category) { entry in
                    FilterChip(title: "\(entry.category.title) (\(entry.count))",
                               isSelected: viewModel.selectedCategory == entry.category) {
                        viewModel.selectedCategory = entry.category
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var progressCard: some View {
        let done = items.filter(\.isPurchased).count
        let progress = ListsViewModel.progress(items)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundStyle(Color.brandPrimary)
                Text("\(done) of \(items.count) items purchased")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            ProgressBar(value: progress)
            HStack {
                Text("Est. total: \(AppFormat.money(ListsViewModel.estimatedTotal(items)))")
                Spacer()
                Label("Optimized by aisle order", systemImage: "circle.fill")
                    .labelStyle(SmallDotLabelStyle())
            }
            .font(.caption)
            .foregroundStyle(Color.textSecondary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// Label with a tiny green dot instead of a full-size icon.
struct SmallDotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color.brandAccent).frame(width: 6, height: 6)
            configuration.title
        }
    }
}

// MARK: - S6 Empty list

struct EmptyListView: View {
    @ObservedObject var viewModel: ListsViewModel
    @EnvironmentObject private var store: AppDataStore

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                VStack(spacing: 16) {
                    EmptyStateView(icon: "basket.fill",
                                   title: "Your Shopping List is Empty",
                                   message: "Add pantry essentials, groceries, or household items. SmartShopper will automatically match them to stores along your everyday routes.")
                    PrimaryButton(title: "Add First Item", icon: "plus") {
                        viewModel.showAddItem = true
                    }
                    if !store.trips.isEmpty {
                        SecondaryButton(title: "Restore from Recent Trip", icon: "clock.arrow.circlepath") {
                            store.restoreFromLastTrip()
                        }
                    }
                }
                .cardStyle(padding: 20)

                HStack {
                    Label("Popular Household Staples", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("TAP TO ADD")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(DemoData.staples) { staple in
                        Button {
                            store.quickAdd(name: staple.name, isFamily: false)
                        } label: {
                            HStack(spacing: 10) {
                                IconCircle(systemName: staple.category.icon, color: staple.category.color, size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(staple.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                    Text(staple.detail)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "plus")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.brandPrimary)
                                    .frame(width: 26, height: 26)
                                    .background(Color.brandMint)
                                    .clipShape(Circle())
                            }
                            .cardStyle(padding: 12)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Add \(staple.name)")
                    }
                }

                // Family sync card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Family Sync is Active", systemImage: "circle.fill")
                            .labelStyle(SmallDotLabelStyle())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                        Spacer()
                        AvatarStack(names: store.members.map(\.name))
                    }
                    Text("Items added by your family will appear in the Family list automatically with store route optimisation.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                    HStack {
                        Label(store.isDemoMode ? "Saved on this device" : "Live with Firebase", systemImage: "checkmark.icloud.fill")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Button("Manage Share") { viewModel.mode = .family }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
        }
    }
}
