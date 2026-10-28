//
//  TripSummaryView.swift
//  SmartShopper
//
//"Trip Summary & Receipt Breakdown": completed badge, stats,
//  itemised digital receipt, family cost split, share receipt.
//  Opened after Finish Shopping Trip, or from a session in History.
//

import SwiftUI

struct TripSummaryView: View {
    let trip: ShoppingTrip
    var isJustFinished = false
    var onDone: (() -> Void)? = nil

    @EnvironmentObject private var router: AppRouter

    // Total per family member (who added each item).
    private var splitByPerson: [(name: String, total: Double, items: [String])] {
        let names = Array(Set(trip.items.map(\.addedByName))).sorted()
        return names.map { name -> (name: String, total: Double, items: [String]) in
            let mine = trip.items.filter { $0.addedByName == name }
            return (name, mine.reduce(0) { $0 + $1.price * Double($1.quantity) }, mine.map(\.name))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                header
                stats
                receipt
                if splitByPerson.count > 1 { familySplit }
                commuteImpact
                if isJustFinished {
                    PrimaryButton(title: "Done & Add to Shopping History", icon: "checkmark") {
                        onDone?()
                    }
                    SecondaryButton(title: "Plan Next Grocery List", icon: "cart.badge.plus") {
                        router.open(.lists)
                        onDone?()
                    }
                }
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .navigationTitle("Trip Summary & Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isJustFinished)
        .toolbar {
            if isJustFinished {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone?() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.heroGreen)
                .frame(width: 84, height: 84)
                .background(Color.brandMint)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Pill(text: "Trip Completed! 🎉", background: .brandMint)
            Text(trip.storeName)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("\(trip.storeArea.isEmpty ? "" : trip.storeArea + " • ")\(trip.date.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Label("\(trip.durationMinutes) min shopping trip", systemImage: "stopwatch")
                .font(.footnote)
                .foregroundStyle(Color.brandPrimary)
            HStack(spacing: 10) {
                ShareLink(item: CSVExporter.receiptText(for: trip)) {
                    Label("Share Receipt", systemImage: "square.and.arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.surfaceMuted)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(icon: "doc.text.fill", value: AppFormat.money(trip.total), label: "Total Charged • \(trip.items.count) items")
            StatTile(icon: "checklist.checked", value: "\(Int((trip.completionRate * 100).rounded()))%", label: "List completion")
            StatTile(icon: "clock.fill", value: "\(trip.durationMinutes)", unit: "min", label: "Store speed")
            StatTile(icon: "arrow.triangle.branch", value: "\(trip.minutesSaved)", unit: "min", label: "Saved vs separate trip")
        }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DIGITAL RECEIPT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                    Text("Order #\(String(trip.id.prefix(6)).uppercased())")
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
            }
            ForEach(trip.items) { item in
                HStack(spacing: 12) {
                    IconCircle(systemName: item.category.icon, color: item.category.color, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.subheadline).foregroundStyle(Color.textPrimary)
                        Text(item.category.aisleText).font(.caption).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AppFormat.money(item.price * Double(item.quantity)))
                            .font(.subheadline.weight(.semibold))
                        Text("Qty \(item.quantity)").font(.caption2).foregroundStyle(Color.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL CHARGED")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                    Text("\(trip.items.count) of \(trip.plannedCount) planned items")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text(AppFormat.money(trip.total))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(12)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .cardStyle()
    }

    private var familySplit: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Family Cost Split")
                    .font(.headline)
                Spacer()
                Pill(text: "\(splitByPerson.count) Members", color: .textSecondary, background: .surfaceMuted)
            }
            Text("Automated split by who added each item")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            ForEach(splitByPerson, id: \.name) { person in
                HStack(spacing: 12) {
                    AvatarCircle(name: person.name, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(.subheadline.weight(.semibold))
                        Text(person.items.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(AppFormat.money(person.total))
                        .font(.subheadline.weight(.bold))
                }
                .padding(12)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine)
            }
        }
        .cardStyle()
    }

    private var commuteImpact: some View {
        HStack(alignment: .top, spacing: 12) {
            IconCircle(systemName: "leaf.fill", size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text("Commute Impact").font(.headline)
                Text("By shopping along your route you saved about \(trip.minutesSaved) minutes compared with a separate errand trip.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .cardStyle()
    }
}
