//
//  Buttons.swift
//  SmartShopper


import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var trailingArrow = false
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.onPrimary)
                } else {
                    if let icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                    if trailingArrow {
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .font(.headline)
            .foregroundStyle(Color.onPrimary)
            .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
            .background(Color.brandPrimary.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
        }
        .buttonStyle(PressableStyle())
        .disabled(!isEnabled || isLoading)
    }
}


struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var background: Color = .brandMint
    var foreground: Color = .brandPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Black "Continue with Apple" button.
struct DarkButton: View {
    let title: String
    var icon: String? = "apple.logo"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.buttonRadius)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
    }
}


struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

}
