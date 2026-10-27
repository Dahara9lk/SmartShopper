//
//  InStoreModeView.swift
//  SmartShopper
//
//  Figma S12 "In-Store Shopping Mode": one item at a time in aisle order,
//  Put in Basket / Skip, upcoming aisle waypoints, Store Path Radar,
//  basket total and Finish Shopping Trip -> Trip Summary (S28).
//

import SwiftUI

struct InStoreModeView: View {
    @StateObject private var viewModel: InStoreViewModel
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var finishedTrip: ShoppingTrip?

    init(items: [ShoppingItem], storeName: String, storeArea: String) {
        _viewModel = StateObject(wrappedValue: InStoreViewModel(items: items, storeName: storeName, storeArea: storeArea))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppLayout.sectionSpacing) {
                    statusStrip
                    progressCard
                    if let current = viewModel.current {
                        waypointCard(current)
                    } else {
                        EmptyStateView(icon: "checkmark.seal.fill",
                                       title: "Everything picked!",
                                       message: "Head to checkout and tap Finish Shopping Trip.")
                            .cardStyle(padding: 20)
                    }
                    if !viewModel.upcomingByAisle.isEmpty { upcomingSection }
                    if !viewModel.picked.isEmpty { collectedSection }
                    radarCard
                }
                .padding(AppLayout.screenPadding)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color.canvas)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Label(viewModel.storeName.uppercased(), systemImage: "circle.fill")
                            .labelStyle(SmallDotLabelStyle())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                            .lineLimit(1)
                        Text("In-Store Shopping Mode")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Exit", systemImage: "xmark")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.dangerRed)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $finishedTrip) { trip in
                TripSummaryView(trip: trip, isJustFinished: true) {
                    dismiss()
                }
            }
        }
    }

    // MARK: Parts

    private var statusStrip: some View {
        HStack {
            Label("Aisle-ordered route active", systemImage: "circle.fill")
                .labelStyle(SmallDotLabelStyle())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            Text("• Zero backtrack").font(.caption).foregroundStyle(Color.textSecondary)
            Spacer()
            if let current = viewModel.current {
                Pill(text: "Aisle \(current.category.aisle)", icon: "arrow.turn.up.right")
            }
        }
        .padding(12)
        .background(Color.brandMintSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(viewModel.pickedCount) of \(viewModel.plannedCount)")
                    .font(.title2.weight(.bold))
                Text("items picked")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Label("~\(viewModel.minutesLeft)m left", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.surfaceMuted)
                    .clipShape(Capsule())
            }
            ProgressBar(value: viewModel.progress)
            HStack {
                Text("RUNNING TOTAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                Text(AppFormat.money(viewModel.basketTotal))
                    .font(.headline)
                    .foregroundStyle(Color.brandPrimary)
                Spacer()
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func waypointCard(_ item: ShoppingItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("IMMEDIATE WAYPOINT", systemImage: "scope")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
                Spacer()
                Text("Step \(viewModel.pickedCount + viewModel.skipped.count + 1) of \(viewModel.plannedCount)")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Pill(text: "Aisle \(item.category.aisle) — \(item.category.title)",
                             color: .onPrimary, background: .brandPrimary, icon: "square.grid.2x2.fill")
                        Text(item.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.textPrimary)
                        Text(item.note.isEmpty ? item.quantityText : "\(item.quantityText) • \(item.note)")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    IconCircle(systemName: item.category.icon, color: item.category.color, size: 64)
                }
                HStack {
                    if !item.addedByName.isEmpty {
                        Label("For \(item.assignedTo ?? item.addedByName)", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text(AppFormat.money(item.lineTotal))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.brandPrimary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(Color.textSecondary)
                    Text("Walk to **Aisle \(item.category.aisle)** (\(item.category.title)) and look for \(item.name).")
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(12)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(Color.brandMintSoft.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                PrimaryButton(title: "Put in Basket", icon: "checkmark.circle.fill") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.35)) { viewModel.putInBasket() }
                }
                Button {
                    withAnimation { viewModel.skip() }
                } label: {
                    Label("Skip / Out", systemImage: "arrow.uturn.right")
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

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Upcoming Aisle Waypoints", actionTitle: "Optimal Order")
            ForEach(viewModel.upcomingByAisle, id: \.aisle) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(group.title)
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Pill(text: "\(group.items.count) item\(group.items.count == 1 ? "" : "s")",
                             color: .textSecondary, background: .surfaceMuted)
                    }
                    ForEach(group.items) { item in
                        Button {
                            withAnimation { viewModel.pick(item) }
                        } label: {
                            HStack(spacing: 12) {
                                CheckBox(isChecked: false)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
                                    Text(item.quantityText).font(.caption).foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Text(AppFormat.money(item.lineTotal))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .padding(12)
                            .background(Color.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pick \(item.name)")
                    }
                }
                .cardStyle()
            }
        }
    }

    private var collectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Collected", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Pill(text: "\(viewModel.picked.count) picked", background: .brandMint)
            }
            ForEach(viewModel.picked) { item in
                Button {
                    withAnimation { viewModel.unpick(item) }
                } label: {
                    HStack(spacing: 12) {
                        CheckBox(isChecked: true)
                        Text(item.name)
                            .strikethrough()
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text(AppFormat.money(item.lineTotal))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), picked")
                .accessibilityHint("Double tap to put it back")
            }
        }
        .cardStyle()
    }

    /// Figma "Store Path Radar": Entrance -> aisles -> Checkout with a dot where you are.
    private var radarCard: some View {
        let stops = viewModel.pathStops
        let currentIndex = viewModel.currentStopIndex
        return VStack(alignment: .leading, spacing: 14) {
            Label("Store Path Radar", systemImage: "location.north.line.fill")
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(index <= currentIndex ? Color.brandPrimary : Color.separatorLine)
                                .frame(width: index == currentIndex ? 18 : 10, height: index == currentIndex ? 18 : 10)
                                .overlay(Circle().stroke(Color.brandMint, lineWidth: index == currentIndex ? 4 : 0))
                            Text(stop.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(index == currentIndex ? Color.brandPrimary : Color.textSecondary)
                        }
                        .frame(width: 70)
                        if index < stops.count - 1 {
                            Rectangle()
                                .fill(index < currentIndex ? Color.brandPrimary : Color.separatorLine)
                                .frame(width: 20, height: 3)
                                .offset(y: -8)
                        }
                    }
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Store path: at \(stops.indices.contains(currentIndex) ? stops[currentIndex] : "checkout")")
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Label("BASKET", systemImage: "bag")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(AppFormat.money(viewModel.basketTotal))
                        .font(.title3.weight(.bold))
                    Text("(\(viewModel.pickedCount) items)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            PrimaryButton(title: "Finish Shopping Trip", trailingArrow: true, isEnabled: viewModel.pickedCount > 0) {
                finishedTrip = store.finishTrip(storeName: viewModel.storeName,
                                                storeArea: viewModel.storeArea,
                                                picked: viewModel.picked,
                                                plannedCount: viewModel.plannedCount,
                                                durationMinutes: viewModel.durationMinutes,
                                                minutesSaved: max(5, viewModel.plannedCount * 2))
            }
            .frame(maxWidth: 230)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
