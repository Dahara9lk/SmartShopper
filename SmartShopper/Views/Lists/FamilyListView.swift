//
//  FamilyListView.swift
//  SmartShopper
//
//  Family list (real-time with Firestore) and S16 "Shop Smarter Together"
//  when nobody else has joined yet. Optional Face ID protection from Biometric settings.
//

import SwiftUI

struct FamilyListView: View {
    @ObservedObject var viewModel: ListsViewModel
    @EnvironmentObject private var store: AppDataStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var security: SecurityViewModel
    @State private var showInvite = false
    @State private var showSoloMessage = false

    private var items: [ShoppingItem] { store.familyItems }
    private var needToBuy: [ShoppingItem] { items.filter { !$0.isPurchased } }
    private var inBasket: [ShoppingItem] { items.filter { $0.isPurchased } }

    var body: some View {
        Group {
            if settings.protectFamilyLists && settings.faceIDEnabled && !viewModel.familyUnlocked {
                lockedCard
            } else if store.members.count <= 1 && items.isEmpty {
                FamilyInviteView(showInvite: $showInvite, onSolo: { viewModel.mode = .myList })
            } else {
                familyList
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet()
                .presentationDetents([.medium, .large])
        }
    }

//Face ID protected

    private var lockedCard: some View {
        VStack(spacing: 16) {
            Spacer()
            EmptyStateView(icon: "lock.fill",
                           title: "Family list is protected",
                           message: "Unlock with \(security.biometryName) to view shared budgets and family items.")
            PrimaryButton(title: "Unlock with \(security.biometryName)", icon: "faceid") {
                Task {
                    viewModel.familyUnlocked = await security.confirmIdentity(reason: "Unlock your family list")
                }
            }
            .frame(maxWidth: 360)
            Spacer()
        }
        .padding(24)
    }

    // list

    private var familyList: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    progressCard
                    familyCircle
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                if needToBuy.isEmpty {
                    Text("Nothing left to buy. Add something below.")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .listRowBackground(Color.surface)
                }
                ForEach(needToBuy) { item in
                    ItemRow(item: item, subtitle: addedText(item), subtitleIcon: "person.crop.circle") {
                        store.togglePurchased(item)
                    }
                    .listRowBackground(Color.surface)
                    .swipeActions {
                        Button(role: .destructive) { store.delete(item) } label: { Label("Delete", systemImage: "trash") }
                        Button { viewModel.itemToEdit = item } label: { Label("Edit", systemImage: "pencil") }
                            .tint(.infoBlue)
                    }
                }
            } header: {
                SectionHeader(title: "Need to Buy (\(needToBuy.count))", actionTitle: "Tap checkmark to complete")
            }

            if !inBasket.isEmpty {
                Section {
                    ForEach(inBasket) { item in
                        ItemRow(item: item,
                                subtitle: "Checked off by \(item.purchasedByName ?? "someone") • \(AppFormat.timeAgo(item.updatedAt))",
                                subtitleIcon: "checkmark.circle") {
                            store.togglePurchased(item)
                        }
                        .listRowBackground(Color.surface)
                    }
                } header: {
                    SectionHeader(title: "Already in Basket (\(inBasket.count))", actionTitle: "Clear") {
                        withAnimation { store.clearCompleted(family: true) }
                    }
                }
            }

            Section {
                addRow
                    .listRowBackground(Color.surface)
            }

            Section {
                PrimaryButton(title: "Start Shopping Mode", icon: "location.north.circle.fill",
                              isEnabled: !needToBuy.isEmpty) {
                    viewModel.showInStoreMode = true
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 52)
        .animation(.default, value: items)
    }

    private func addedText(_ item: ShoppingItem) -> String {
        var text = "Added by \(item.addedByName == store.userName ? "You" : item.addedByName) • \(AppFormat.timeAgo(item.createdAt))"
        if let assigned = item.assignedTo, assigned != "You" {
            text += " • for \(assigned)"
        }
        return text
    }

    private var progressCard: some View {
        let progress = ListsViewModel.progress(items)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.household?.name ?? "Family List")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(inBasket.count) of \(items.count) items completed")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            ProgressBar(value: progress)
        }
        .cardStyle()
    }

    private var familyCircle: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Family Circle (\(store.members.count))", actionTitle: "Invite") {
                showInvite = true
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(store.members) { member in
                        VStack(spacing: 6) {
                            AvatarCircle(name: member.name, size: 48, showOnline: true)
                            Text(member.id == store.profile?.id ? "You" : member.name)
                                .font(.caption)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                    Button {
                        showInvite = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.headline)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 48, height: 48)
                                .background(Color.brandMintSoft)
                                .clipShape(Circle())
                            Text("Invite")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(width: 60)
                    }
                    .accessibilityLabel("Invite family member")
                }
            }
        }
        .cardStyle()
    }

    // "Add item to family list..." + Assign chips
    private var addRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "cart.badge.plus")
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.brandMintSoft)
                    .clipShape(Circle())
                TextField("Add item to family list...", text: $viewModel.familyDraft)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .submitLabel(.done)
                    .onSubmit(addFamilyItem)
                Button("Add", action: addFamilyItem)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 42)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Assign:")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    ForEach(assignOptions, id: \.self) { name in
                        Button {
                            viewModel.assignTo = name
                        } label: {
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(viewModel.assignTo == name ? Color.onPrimary : Color.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.assignTo == name ? Color.brandPrimary : Color.surfaceMuted)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    if let prediction = ItemClassifierService.shared.predict(viewModel.familyDraft) {
                        Text("Category:")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.leading, 6)
                        CategoryBadge(category: prediction.category)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var assignOptions: [String] {
        ["You"] + store.members.filter { $0.id != store.profile?.id }.map(\.name)
    }

    private func addFamilyItem() {
        let name = viewModel.familyDraft
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.quickAdd(name: name, isFamily: true, assignedTo: viewModel.assignTo)
        viewModel.familyDraft = ""
    }
}

// MARK: - S16 Shop Smarter Together

struct FamilyInviteView: View {
    @Binding var showInvite: Bool
    let onSolo: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                ZStack {
                    Circle().fill(Color.brandMintSoft).frame(width: 150, height: 150)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandPrimary)
                    Image(systemName: "heart.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.brandPrimary, Color.surface)
                        .offset(x: 46, y: 46)
                }
                .padding(.top, 8)
                .accessibilityHidden(true)

                Text("Shop Smarter Together")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("Collaborate on grocery runs in real-time. Invite family or roommates to add items, view live shopping progress, and split trips effortlessly.")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 18) {
                    benefit(icon: "arrow.triangle.2.circlepath", title: "Real-Time Sync",
                            text: "Items checked off in-aisle sync instantly across all shared household devices.")
                    benefit(icon: "person.text.rectangle.fill", title: "Contributor Badges",
                            text: "Always know who requested which ingredient so you never grab the wrong brand again.")
                    benefit(icon: "location.fill", title: "Shared Commute Alerts",
                            text: "Smart geo-reminders notify whichever family member is passing near the right shop.")
                }
                .cardStyle(padding: 18)

                PrimaryButton(title: "Invite via Messages or AirDrop", icon: "square.and.arrow.up") {
                    showInvite = true
                }
                SecondaryButton(title: "Generate Invite Link or QR Code", icon: "qrcode") {
                    showInvite = true
                }

                Button(action: onSolo) {
                    HStack {
                        Image(systemName: "house.fill").foregroundStyle(Color.textSecondary)
                        Text("Prefer to shop solo? Keep your lists private.")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("Switch ›")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .padding(14)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
        }
    }

    private func benefit(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconCircle(systemName: icon, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Color.textPrimary)
                Text(text).font(.subheadline).foregroundStyle(Color.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// Invite sheet (ShareLink + QR code)

struct InviteSheet: View {
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    private var code: String { store.household?.inviteCode ?? "------" }
    private var message: String {
        "Join my \(store.household?.name ?? "family") shopping list on SmartShopper! Open the app, tap Create Account > Enter Invite Code and type: \(code)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Share this code with your family")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Text(code)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Color.brandPrimary)
                    .textSelection(.enabled)
                    .accessibilityLabel("Invite code \(code.map(String.init).joined(separator: " "))")
                if let qr = QRCodeMaker.image(from: message) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 180, height: 180)
                        .padding(10)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("QR code for the invite")
                }
                ShareLink(item: message) {
                    Label("Invite via Messages or AirDrop", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(Color.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: AppLayout.buttonHeight)
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.buttonRadius))
                }
                Spacer()
            }
            .padding(24)
            .navigationTitle("Invite Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
