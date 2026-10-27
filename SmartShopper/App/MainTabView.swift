//
//  MainTabView.swift
//  SmartShopper
//
//  iPhone: bottom tab bar with 5 tabs (Home, Lists, Smart Map, History, Profile).
//  iPad:   NavigationSplitView - sidebar on the left, the chosen section on the right.
//          (Multi-device adaptation for LO1 / Component 5.)
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .sheet(isPresented: $router.showActivitySheet) {
            ActivitySheet()
        }
        // Tapping a store notification opens Smart Map
        .onReceive(NotificationCenter.default.publisher(for: .openSmartMap)) { _ in
            router.open(.smartMap)
        }
        .task {
            // Ask for notification permission once the user is signed in
            await NotificationService.shared.requestPermission()
        }
    }

    // MARK: iPhone

    private var iPhoneLayout: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                screen(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(.brandPrimary)
    }

    // MARK: iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        router.open(tab)
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .foregroundStyle(router.selectedTab == tab ? Color.brandPrimary : Color.textPrimary)
                            .fontWeight(router.selectedTab == tab ? .semibold : .regular)
                    }
                    .listRowBackground(router.selectedTab == tab ? Color.brandMintSoft : Color.clear)
                    .accessibilityAddTraits(router.selectedTab == tab ? .isSelected : [])
                }
            }
            .navigationTitle("SmartShopper")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            screen(for: router.selectedTab)
        }
        .tint(.brandPrimary)
    }

    /// Each tab has its own NavigationStack so pushing inside one tab doesn't affect the others.
    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: NavigationStack { HomeView() }
        case .lists: NavigationStack { ListsView() }
        case .smartMap: NavigationStack { SmartMapView() }
        case .history: NavigationStack { HistoryView() }
        case .profile: NavigationStack { ProfileView() }
        }
    }
}
