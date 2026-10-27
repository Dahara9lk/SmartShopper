//
//  Header.swift
//  SmartShopper
//
//  "[logo] SmartShopper / Lists        (bell) (avatar)" - the header on every tab.
//

import SwiftUI

struct AppHeader: View {
    let title: String
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: AppDataStore

    var body: some View {
        HStack(spacing: 8) {
            AppLogoBadge()
            Text("SmartShopper")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text("/")
                .font(.title3)
                .foregroundStyle(Color.textTertiary)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)

            // Bell - opens the activity / notifications sheet
            Button {
                router.showActivitySheet = true
            } label: {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 36, height: 36)
                    .overlay(alignment: .topTrailing) {
                        if !store.activity.isEmpty {
                            Circle().fill(Color.brandAccent).frame(width: 8, height: 8).offset(x: -6, y: 6)
                        }
                    }
            }
            .accessibilityLabel("Notifications")

            // Avatar - jumps to Profile
            Button {
                router.open(.profile)
            } label: {
                AvatarCircle(name: store.userName, size: 34)
            }
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 8)
        .background(Color.canvas)
    }
}

/// Circle with the person's first letter (instead of a photo).
struct AvatarCircle: View {
    let name: String
    var size: CGFloat = 36
    var showOnline = false

    /// Same name -> same colour, so "Mom" is always the same colour.
    private var color: Color {
        let colors: [Color] = [.brandPrimary, .orange, .blue, .purple, .pink, .teal]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[sum % colors.count]
    }

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.surface, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if showOnline {
                    Circle()
                        .fill(Color.brandAccent)
                        .frame(width: size * 0.28, height: size * 0.28)
                        .overlay(Circle().stroke(Color.surface, lineWidth: 2))
                }
            }
            .accessibilityLabel(name)
    }
}

/// Overlapping avatars "M D A".
struct AvatarStack: View {
    let names: [String]
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(Array(names.prefix(4).enumerated()), id: \.offset) { _, name in
                AvatarCircle(name: name, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family: " + names.joined(separator: ", "))
    }
}

/// Sheet opened from the bell - recent family activity.
struct ActivitySheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.activity.isEmpty {
                    Text("No activity yet. When family members add or check off items, it appears here.")
                        .foregroundStyle(Color.textSecondary)
                }
                ForEach(store.activity) { event in
                    HStack(spacing: 12) {
                        AvatarCircle(name: event.actorName, size: 32)
                        VStack(alignment: .leading) {
                            Text(event.text).font(.subheadline)
                            Text(AppFormat.timeAgo(event.date))
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
