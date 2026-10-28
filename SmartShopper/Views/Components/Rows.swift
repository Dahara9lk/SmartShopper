//
//  Rows.swift
//  SmartShopper
//
//  List rows: shopping item rows and the settings rows used in Profile.
//

import SwiftUI

// Round-cornered checkbox used on item rows.
struct CheckBox: View {
    let isChecked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(isChecked ? Color.brandPrimary : Color.surfaceMuted)
                .frame(width: 26, height: 26)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.onPrimary)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isChecked)
        .accessibilityHidden(true)
    }
}

// One shopping item: checkbox, name, sub line, category badge.

struct ItemRow: View {
    let item: ShoppingItem
    /// e.g. "Aisle 3 • Dairy" or "Added by Mom • 15m ago"
    var subtitle: String? = nil
    var subtitleIcon: String? = nil
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                CheckBox(isChecked: item.isPurchased)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.titleWithQuantity)
                            .font(.body.weight(.medium))
                            .foregroundStyle(item.isPurchased ? Color.textTertiary : Color.textPrimary)
                            .strikethrough(item.isPurchased)
                            .multilineTextAlignment(.leading)
                        if item.isUrgent && !item.isPurchased {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.warningOrange)
                                .accessibilityLabel("Urgent")
                        }
                    }
                    if let subtitle {
                        HStack(spacing: 4) {
                            if let subtitleIcon {
                                Image(systemName: subtitleIcon).font(.caption2)
                            }
                            Text(subtitle)
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                CategoryBadge(category: item.category)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.quantityText), \(item.category.title)")
        .accessibilityValue(item.isPurchased ? "Purchased" : "Not purchased")
        .accessibilityHint("Double tap to \(item.isPurchased ? "mark as not purchased" : "mark as purchased")")
    }
}

// Groups settings rows in a white card with a caps title above.
struct SettingsGroup<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, actionTitle: trailing)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
            }
            .buttonStyle(.plain)      // NavigationLinks inside keep our own colours
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: AppLayout.cardRadius).stroke(Color.separatorLine, lineWidth: 1))
        }
    }
}

// Icon + title + subtitle + switch.
struct SettingsToggleRow: View {
    let icon: String
    var iconColor: Color = .brandPrimary
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                IconCircle(systemName: icon, color: iconColor, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(Color.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .tint(.brandPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// Icon + title + value text + chevron. Tapping runs the action.
struct SettingsValueRow: View {
    let icon: String
    var iconColor: Color = .brandPrimary
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var valueColor: Color = .textSecondary
    var titleColor: Color = .textPrimary
    var showChevron = true
    var action: (() -> Void)? = nil

    var body: some View {
        // Only a button when there is something to do - otherwise a plain row
        // (so it can also be used as a NavigationLink or Menu label).
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            IconCircle(systemName: icon, color: iconColor, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// Thin line between rows inside a SettingsGroup.
struct RowDivider: View {
    var body: some View {
        Divider().overlay(Color.separatorLine).padding(.leading, 60)
    }
}
