//
//  SmartShopperWidget.swift
//  SmartShopperWidget



import WidgetKit
import SwiftUI

// Data for the widget

struct ListEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ListProvider: TimelineProvider {

    // Grey "loading" version.
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: Date(), snapshot: .sample)
    }

    // Shown in the widget gallery.
    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> Void) {
        let data = context.isPreview ? WidgetSnapshot.sample : WidgetStorage.load()
        completion(ListEntry(date: Date(), snapshot: data))
    }

    // The app reloads the widget every time the list changes.
    // This 30 minute refresh is just a backup.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ListEntry>) -> Void) {
        let entry = ListEntry(date: Date(), snapshot: WidgetStorage.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// Colours (same green as the app, lighter in dark mode)

extension Color {
    static let widgetGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.70, blue: 0.51, alpha: 1)     // #2BB383
            : UIColor(red: 0.004, green: 0.416, blue: 0.286, alpha: 1)  // #016A49
    })
}

// Views

struct SmartShopperWidgetView: View {
    let entry: ListEntry
    @Environment(\.widgetFamily) private var family

    private var data: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .accessoryRectangular: lockRectangular
        case .accessoryCircular: lockCircular
        case .accessoryInline: lockInline
        default: smallView
        }
    }

    // Home Screen - small
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "cart.fill")
                .font(.title3)
                .foregroundStyle(Color.widgetGreen)
            Spacer()
            Text("\(data.itemsLeft)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(data.itemsLeft == 1 ? "item left" : "items left")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let first = data.nextItems.first {
                Text("Next: \(first)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.widgetGreen)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // Home Screen - medium
    private var mediumView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("SmartShopper", systemImage: "cart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetGreen)
                Spacer()
                Text("\(data.itemsLeft)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("items left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !data.totalText.isEmpty {
                    Text("Est. \(data.totalText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if data.nextItems.isEmpty {
                    Text("Your list is empty")
                        .font(.subheadline.weight(.semibold))
                    Text("Add items in the app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(data.nextItems, id: \.self) { name in
                        Label(name, systemImage: "circle")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let shop = data.bestShopName {
                    Label("\(shop) • \(data.bestShopMatches) items", systemImage: "mappin.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.widgetGreen)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // Lock Screen - rectangle under the clock
    private var lockRectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("\(data.itemsLeft) items left", systemImage: "cart.fill")
                .font(.headline)
            if let first = data.nextItems.first {
                Text("Next: \(first)").lineLimit(1)
            }
            if let shop = data.bestShopName {
                Text(shop).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // Lock Screen - small circle
    private var lockCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "cart.fill").font(.caption)
                Text("\(data.itemsLeft)").font(.title3.weight(.bold))
            }
        }
        .accessibilityLabel("\(data.itemsLeft) items left to buy")
    }

    // Lock Screen - one line above the clock
    private var lockInline: some View {
        Label("\(data.itemsLeft) items to buy", systemImage: "cart.fill")
    }

    // What VoiceOver reads for the whole widget.
    private var accessibilitySummary: String {
        var text = "SmartShopper. \(data.itemsLeft) items left."
        if !data.nextItems.isEmpty { text += " Next: \(data.nextItems.joined(separator: ", "))." }
        if let shop = data.bestShopName { text += " Best shop: \(shop), \(data.bestShopMatches) items." }
        return text
    }
}

// The widget

struct SmartShopperWidget: Widget {
    let kind = "SmartShopperWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ListProvider()) { entry in
            SmartShopperWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shopping List")
        .description("Items left to buy and the best shop nearby.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    SmartShopperWidget()
} timeline: {
    ListEntry(date: .now, snapshot: .sample)
}
