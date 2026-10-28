//
//  Cards.swift
//  SmartShopper
//
//  White rounded cards, section headers, badges and icon circles used on every screen.
//

import SwiftUI

// Wraps any content in the white rounded Figma card.
struct CardView<Content: View>: View {
    var padding: CGFloat = AppLayout.cardPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardRadius)
                    .stroke(Color.separatorLine, lineWidth: 1)
            )
    }
}

extension View {
    // Same look as CardView, as a modifier.
    func cardStyle(padding: CGFloat = AppLayout.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardRadius)
                    .stroke(Color.separatorLine, lineWidth: 1)
            )
    }
}

// "REMAINING ITEMS (5)              Swipe left for actions"
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            if let actionTitle {
                if let action {
                    Button(actionTitle, action: action)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                } else {
                    Text(actionTitle)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// Small rounded label like "Matched", "Step 1 of 2", "+4 this mo".
struct Pill: View {
    let text: String
    var color: Color = .brandPrimary
    var background: Color? = nil
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background ?? color.opacity(0.14))
        .clipShape(Capsule())
    }
}

// Category badge on item rows ("Dairy").
struct CategoryBadge: View {
    let category: ItemCategory

    var body: some View {
        Text(category.title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(category.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Category \(category.title)")
    }
}

// Coloured circle with an SF Symbol inside (used on settings rows and cards).
struct IconCircle: View {
    let systemName: String
    var color: Color = .brandPrimary
    var size: CGFloat = 36
    var filled = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(filled ? Color.onPrimary : color)
            .frame(width: size, height: size)
            .background(filled ? color : color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

// The green SmartShopper logo badge in the header.
struct AppLogoBadge: View {
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: "bag.fill.badge.plus")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [Color.brandAccent, Color.brandPrimary],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

// Horizontal progress bar (capsule).
struct ProgressBar: View {
    let value: Double            // 0...1
    var color: Color = .brandPrimary
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.surfaceMuted)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.easeInOut, value: value)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// Circular "38%" ring on the Home active list card.
struct ProgressRing: View {
    let value: Double
    var size: CGFloat = 52
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Color.surfaceMuted, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.textPrimary)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut, value: value)
        .accessibilityElement()
        .accessibilityLabel("List progress")
        .accessibilityValue("\(Int(value * 100)) percent done")
    }
}

// Stat tile on History / Trip Summary ("24 Shopping Trips").
struct StatTile: View {
    let icon: String
    let value: String
    var unit: String? = nil
    let label: String
    var badge: String? = nil
    var badgeColor: Color = .brandPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconCircle(systemName: icon, size: 32)
                Spacer()
                if let badge {
                    Pill(text: badge, color: badgeColor)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
        }
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// Empty / error state with a big icon
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var iconColor: Color = .brandPrimary

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 88, height: 88)
                .background(iconColor.opacity(0.14))
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// Light green info card with a shield icon ("On-Device Route Mapping").
struct InfoBanner: View {
    let icon: String
    let title: String
    let message: String
    var color: Color = .brandPrimary
    var background: Color = .brandMintSoft

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconCircle(systemName: icon, color: color, size: 34, filled: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
        .accessibilityElement(children: .combine)
    }
}
