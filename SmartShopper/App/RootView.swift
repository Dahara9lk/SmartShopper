//
//  RootView.swift
//  SmartShopper

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var security: SecurityViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var didStart = false

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            switch store.authState {
            case .loading:
                SplashView()
            case .signedOut:
                AuthFlowView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.opacity)
            }

            // Face ID lock sits on top of everything
            if security.isLocked && store.authState == .signedIn {
                LockContainerView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.authState)
        .animation(.easeInOut(duration: 0.25), value: security.isLocked)
        .task {
            guard !didStart else { return }
            didStart = true
            security.lockOnLaunch()
            await store.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: security.appDidEnterBackground()
            case .active: security.appDidBecomeActive()
            default: break
            }
        }
        .sheet(isPresented: $security.showPasscodeSetup) {
            PasscodeSetupView()
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { store.errorMessage != nil },
                                    set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            AppLogoBadge(size: 84)
            Text("SmartShopper")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.textPrimary)
            ProgressView()
        }
    }
}
