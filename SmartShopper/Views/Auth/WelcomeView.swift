//
//  WelcomeView.swift
//  SmartShopper
//
//  Figma S22 - onboarding. 3 swipeable pages, page dots, Get Started.
//  (Pages 2 and 3 are not in the Figma file - they follow the same style.)
//

import SwiftUI

/// Signed-out area: Welcome -> Create Account / Sign In.
struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}

struct WelcomeView: View {
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                pageOne.tag(0)
                featurePage(icon: "person.3.fill",
                            title: "Shop Smarter Together",
                            message: "Share one live list with your family. See who added what and who already picked it up.").tag(1)
                featurePage(icon: "location.fill.viewfinder",
                            title: "Never Miss a Store",
                            message: "SmartShopper alerts you when you pass a shop that has items from your list.").tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page dots (the long one is the current page)
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.brandPrimary : Color.separatorLine)
                        .frame(width: index == page ? 22 : 8, height: 8)
                }
            }
            .animation(.easeInOut, value: page)
            .padding(.vertical, 16)
            .accessibilityElement()
            .accessibilityLabel("Page \(page + 1) of 3")

            VStack(spacing: 14) {
                NavigationLink {
                    AuthContainerView(startMode: .createAccount)
                } label: {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
                }

                NavigationLink {
                    AuthContainerView(startMode: .signIn)
                } label: {
                    (Text("Already have an account? ").foregroundColor(.textSecondary)
                     + Text("Sign In").foregroundColor(.brandPrimary).bold())
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Figma S22 page 1
    private var pageOne: some View {
        ScrollView {
            VStack(spacing: 18) {
                AppLogoBadge(size: 84)
                    .padding(.top, 24)
                Pill(text: "SMART GROCERY CO-PILOT", icon: "checkmark.seal.fill")
                Text("SmartShopper")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Intelligent shopping for you and your family.")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    featureCard(icon: "scope", title: "On-Device Smart Matching", badge: "Radar",
                                text: "Connects your shopping list items with nearby and along-route stores using real-time location awareness.")
                    featureCard(icon: "person.2.fill", title: "Real-Time Family Lists", badge: nil,
                                text: "Collaborate with family members. See who added what in real time (e.g. Mom, Dad, Alex).")
                    featureCard(icon: "storefront.fill", title: "Smart Recommendations", badge: nil,
                                text: "Get timely notifications when passing a store stocking the items you need.")
                }

                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy-First Architecture").font(.subheadline.weight(.medium))
                        Text("Item matching runs on your iPhone with Core ML.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Pill(text: "iOS HIG", color: .textSecondary, background: .surfaceMuted)
                }
                .padding(14)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
            }
            .padding(.horizontal, 20)
        }
    }

    private func featureCard(icon: String, title: String, badge: String?, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconCircle(systemName: icon, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    if let badge {
                        Pill(text: badge)
                    }
                }
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func featurePage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 140, height: 140)
                .background(Color.brandMintSoft)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(AppEnvironment.shared.store)
        .environmentObject(AppEnvironment.shared.settings)
        .environmentObject(AppEnvironment.shared.security)
}
