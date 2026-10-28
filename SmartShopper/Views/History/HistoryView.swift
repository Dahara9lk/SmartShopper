//
//  HistoryView.swift
//  SmartShopper
//
// "Shopping History & Statistics" (stat tiles, weekly chart with Swift Charts,
//  category distribution, recent sessions, CSV export) and S18 empty state.
//

import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showManualReceipt = false

    private var stats: HistoryStats { HistoryStats(trips: store.trips) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppLayout.sectionSpacing) {
                if store.trips.isEmpty {
                    emptyState
                } else {
                    statTiles
                    weeklyChart
                    categoryCard
                    recentSessions
                    if let milestone = stats.milestoneText {
                        InfoBanner(icon: "trophy.fill", title: "MILESTONE UNLOCKED", message: milestone)
                    }
                }
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Color.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(title: "History")
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: ShoppingTrip.self) { trip in
            TripSummaryView(trip: trip)
        }
        .sheet(isPresented: $showManualReceipt) {
            ManualReceiptSheet()
                .presentationDetents([.medium])
        }
    }

    // Stat tiles

    private var statColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: sizeClass == .regular ? 4 : 2)
    }

    private var statTiles: some View {
        LazyVGrid(columns: statColumns, spacing: 10) {
            StatTile(icon: "basket.fill", value: "\(stats.tripCount)", label: "Shopping Trips",
                     badge: "+\(stats.tripsThisMonth()) this mo")
            StatTile(icon: "checklist.checked", value: "\(stats.itemsCollected)", label: "Items Collected",
                     badge: "\(Int((stats.averageCompletion * 100).rounded()))%")
            StatTile(icon: "clock.fill", value: String(format: "%.1f", stats.hoursSaved), unit: "hrs",
                     label: "Aisle Time Saved", badge: "SmartRoute")
            StatTile(icon: "doc.text.fill", value: AppFormat.money(stats.totalSpend), label: "Total Spend Logged",
                     badge: "~\(AppFormat.money(stats.averagePerTrip))/trip", badgeColor: .textSecondary)
        }
    }

    // Weekly chart (Swift Charts)

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weekly Shopping Intensity", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if let peak = stats.peakDay {
                    Pill(text: "Peak: \(peak)", color: .textSecondary, background: .surfaceMuted)
                }
            }
            Chart(stats.tripsByWeekday) { day in
                BarMark(x: .value("Day", "\(day.id)"),
                        y: .value("Trips", day.trips))
                    .foregroundStyle(day.trips == stats.tripsByWeekday.map(\.trips).max() ? Color.brandPrimary : Color.brandMint)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if day.trips > 0 {
                            Text("\(day.trips)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        Text(Self.dayLetter(value.as(String.self)))
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 160)
            .accessibilityLabel("Trips per weekday")
        }
        .cardStyle()
    }

    // "1" -> "M", "7" -> "S" for the chart's x axis.
    static func dayLetter(_ raw: String?) -> String {
        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        guard let raw, let index = Int(raw), index >= 1, index <= 7 else { return "" }
        return letters[index - 1]
    }

    // Category distribution

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category Distribution")
                    .font(.headline)
                Spacer()
                Text("\(stats.itemsCollected) Total Items")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            // One stacked bar made of coloured pieces
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(stats.categoryShares) { share in
                        Rectangle()
                            .fill(share.category.color)
                            .frame(width: max(4, proxy.size.width * share.share - 2))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 10)
            .accessibilityHidden(true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(stats.categoryShares) { share in
                    HStack(spacing: 6) {
                        Circle().fill(share.category.color).frame(width: 8, height: 8)
                        Text(share.category.title).font(.caption)
                        Text("\(Int((share.share * 100).rounded()))% (\(share.count))")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .cardStyle()
    }

    // Recent sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Sessions")
                    .font(.title3.weight(.semibold))
                Pill(text: "\(stats.tripCount)", color: .textSecondary, background: .surfaceMuted)
                Spacer()
                if let url = CSVExporter.writeFile(trips: store.trips) {
                    ShareLink(item: url) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
            }
            ForEach(store.trips) { trip in
                NavigationLink(value: trip) {
                    sessionCard(trip)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionCard(_ trip: ShoppingTrip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                IconCircle(systemName: trip.items.first?.category.icon ?? "cart.fill",
                           color: trip.items.first?.category.color ?? .brandPrimary, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.storeName)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Text("\(trip.date.formatted(date: .abbreviated, time: .shortened)) • \(trip.storeArea)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(AppFormat.money(trip.total))
                        .font(.headline)
                    Pill(text: trip.completionText, color: trip.completionRate >= 1 ? .brandPrimary : .infoBlue)
                }
            }
            Text(trip.items.map(\.name).joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Label("Saved \(trip.minutesSaved) mins", systemImage: "arrow.triangle.branch")
                    .foregroundStyle(Color.brandPrimary)
                if trip.familyMemberCount > 1 {
                    Label("\(trip.familyMemberCount) family", systemImage: "person.2.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.textTertiary)
            }
            .font(.caption)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    //  empty state

    private var emptyState: some View {
        VStack(spacing: AppLayout.sectionSpacing) {
            LazyVGrid(columns: statColumns, spacing: 10) {
                StatTile(icon: "basket.fill", value: "0", unit: "runs", label: "No activity recorded")
                StatTile(icon: "checklist", value: "0", unit: "items", label: "Basket empty")
                StatTile(icon: "dollarsign.circle.fill", value: AppFormat.money(0), label: "Deals & discounts")
                StatTile(icon: "timer", value: "--", unit: "rate", label: "Trip efficiency")
            }

            VStack(spacing: 12) {
                EmptyStateView(icon: "receipt.fill",
                               title: "No Shopping Trips Recorded Yet",
                               message: "Your completed trips, spending trends and route time savings will automatically appear here once you finish your first run.")
                Label("Historical insights unlock after trip 1", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandMintSoft)
                    .clipShape(Capsule())
            }
            .cardStyle(padding: 20)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("How It Works", systemImage: "safari.fill")
                        .font(.headline)
                    Spacer()
                    Pill(text: "3 Easy Steps", background: .brandMint)
                }
                step(1, "Build your shopping list", "Add weekly staples - on-device AI sorts them into shop categories.")
                step(2, "Start In-Store Mode", "SmartShopper sorts items aisle-by-aisle so you grab everything in one fast route.")
                step(3, "Finish trip to log stats", "Tap 'Finish Shopping Trip' at checkout. We store the receipt and your time saved.")
            }
            .cardStyle()

            PrimaryButton(title: "Plan First Grocery Run", icon: "cart.badge.plus") {
                router.open(.lists)
            }
            SecondaryButton(title: "Log Past Receipt Manually", icon: "doc.text.viewfinder",
                            background: .surfaceMuted, foreground: .textPrimary) {
                showManualReceipt = true
            }
            Button {
                store.loadDemoHistory()
            } label: {
                Label("Load Demo History Data", systemImage: "flask.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func step(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 32, height: 32)
                .background(Color.brandMint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// "Log Past Receipt Manually"
struct ManualReceiptSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var storeName = ""
    @State private var totalText = ""
    @State private var itemCount = 5
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Store name", text: $storeName)
                TextField("Total spent", text: $totalText)
                    .keyboardType(.decimalPad)
                Stepper("Items: \(itemCount)", value: $itemCount, in: 1...100)
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Log Past Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let total = Double(totalText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        store.logManualTrip(storeName: storeName.isEmpty ? "Manual entry" : storeName,
                                            total: total, itemCount: itemCount, date: date)
                        dismiss()
                    }
                    .disabled(Double(totalText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }
}
