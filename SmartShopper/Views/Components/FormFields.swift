//
//  FormFields.swift
//  SmartShopper


import SwiftUI

// Label above a grey rounded field with an icon (Full Name, Email Address...).
struct LabeledField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure = false
    @Binding var showSecure: Bool
    var trailingNote: String? = nil
    var trailingNoteColor: Color = .brandPrimary
    var showError = false
    var errorText: String? = nil

    init(label: String, icon: String, placeholder: String, text: Binding<String>,
         keyboard: UIKeyboardType = .default, contentType: UITextContentType? = nil,
         isSecure: Bool = false, showSecure: Binding<Bool> = .constant(false),
         trailingNote: String? = nil, trailingNoteColor: Color = .brandPrimary,
         showError: Bool = false, errorText: String? = nil) {
        self.label = label
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.keyboard = keyboard
        self.contentType = contentType
        self.isSecure = isSecure
        self._showSecure = showSecure
        self.trailingNote = trailingNote
        self.trailingNoteColor = trailingNoteColor
        self.showError = showError
        self.errorText = errorText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if let trailingNote {
                    Text(trailingNote)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(trailingNoteColor)
                }
            }
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Group {
                    if isSecure && !showSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(keyboard == .emailAddress || isSecure ? .never : .words)
                .autocorrectionDisabled(keyboard == .emailAddress || isSecure)
                .foregroundStyle(Color.textPrimary)

                if isSecure {
                    Button {
                        showSecure.toggle()
                    } label: {
                        Image(systemName: showSecure ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityLabel(showSecure ? "Hide password" : "Show password")
                } else if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.textTertiary)
                    }
                    .accessibilityLabel("Clear \(label)")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.fieldRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.fieldRadius)
                    .stroke(showError ? Color.dangerRed : Color.clear, lineWidth: 1.5)
            )
            if showError, let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(Color.dangerRed)
            }
        }
    }
}

// White-pill-on-grey segmented control (Sign In / Create Account, New Circle / Invite Code).
struct CapsuleSegment: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    Text(title)
                        .font(.subheadline.weight(selection == index ? .semibold : .regular))
                        .foregroundStyle(selection == index ? Color.brandPrimary : Color.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(selection == index ? Color.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(selection == index ? 0.06 : 0), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// Filter chip ("All (8)", "Groceries (5)") - selected one is filled green.
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(title)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.onPrimary : Color.textPrimary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color.brandPrimary : Color.surfaceMuted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// Small "Remaining to pick" chip with a tiny checkbox.
struct ItemChip: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.textTertiary, lineWidth: 1.2)
                .frame(width: 14, height: 14)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// Simple wrapping layout so chips flow onto new lines (iOS 16+ Layout protocol).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
