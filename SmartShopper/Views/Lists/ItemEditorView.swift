//
//  ItemEditorView.swift
//  SmartShopper
//
//  Figma S5 "Item Detail": name, quick chips, quantity stepper, unit, category
//  (pre-filled by the on-device Core ML model), store preference, destination list, note.
//

import SwiftUI

struct ItemEditorView: View {
    @StateObject private var viewModel: ItemEditorViewModel
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    init(item: ShoppingItem? = nil, startInFamily: Bool = false) {
        _viewModel = StateObject(wrappedValue: ItemEditorViewModel(item: item, startInFamily: startInFamily))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    quickPicks
                    quantityAndUnit
                    categorySection
                    preferencesCard
                }
                .padding(AppLayout.screenPadding)
            }
            .background(Color.canvas)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    PrimaryButton(title: viewModel.isEditing ? "Save Changes" : "Add to Shopping List",
                                  icon: "cart.badge.plus",
                                  isEnabled: viewModel.canSave) {
                        save()
                    }
                    if viewModel.isFamily {
                        Text("Syncs instantly with \(max(store.members.count, 1)) family member\(store.members.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle(viewModel.isEditing ? "Edit Item" : "Item Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !viewModel.isEditing { nameFocused = true }
            }
        }
    }

    private func save() {
        guard let profile = store.profile else { return }
        let item = viewModel.makeItem(ownerId: profile.id, addedBy: profile.name)
        store.save(item)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    // MARK: Parts

    private var nameField: some View {
        HStack(spacing: 10) {
            IconCircle(systemName: viewModel.category.icon, color: viewModel.category.color, size: 36, filled: true)
            TextField("Item name, e.g. Almond Milk", text: $viewModel.name)
                .font(.title3.weight(.semibold))
                .focused($nameFocused)
                .submitLabel(.done)
            if !viewModel.name.isEmpty {
                Button {
                    viewModel.name = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textTertiary)
                }
                .accessibilityLabel("Clear name")
            }
        }
        .cardStyle(padding: 12)
    }

    private var quickPicks: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Label("Quick:", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                ForEach(DemoData.quickPicks, id: \.self) { pick in
                    FilterChip(title: pick, isSelected: viewModel.name == pick) {
                        viewModel.useQuickPick(pick)
                    }
                }
            }
        }
    }

    private var quantityAndUnit: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("QUANTITY").font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                HStack(spacing: 0) {
                    stepButton(icon: "minus", label: "Decrease quantity") { viewModel.decrease() }
                    Text("\(viewModel.quantity)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 44)
                        .accessibilityLabel("Quantity \(viewModel.quantity)")
                    stepButton(icon: "plus", label: "Increase quantity") { viewModel.increase() }
                }
                .padding(6)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.separatorLine))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("MEASURE / UNIT").font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(MeasureUnit.allCases) { unit in
                        Button {
                            viewModel.unit = unit
                        } label: {
                            Text(unit.title)
                                .font(.subheadline.weight(viewModel.unit == unit ? .semibold : .regular))
                                .foregroundStyle(viewModel.unit == unit ? Color.brandPrimary : Color.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(viewModel.unit == unit ? Color.surface : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewModel.unit == unit ? .isSelected : [])
                    }
                }
                .padding(4)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func stepButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
                .frame(width: 40, height: 40)
                .background(Color.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(label)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CATEGORY").font(.caption.weight(.semibold)).foregroundStyle(Color.textSecondary)
                Spacer()
                if let prediction = viewModel.prediction, !viewModel.categoryPickedByHand {
                    Label("On-device AI: \(prediction.category.title) \(prediction.confidenceText)", systemImage: "cpu")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(prediction.isLowConfidence ? Color.warningOrange : Color.brandPrimary)
                        .accessibilityLabel("Core ML suggests \(prediction.category.title), \(prediction.confidenceText) confident")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ItemCategory.allCases) { category in
                        FilterChip(title: category.title, icon: category.icon,
                                   isSelected: viewModel.category == category) {
                            viewModel.pickCategory(category)
                        }
                    }
                }
            }
            if let prediction = viewModel.prediction, prediction.isLowConfidence, !viewModel.categoryPickedByHand {
                Text("Not sure about this one - tap the right category if it's wrong.")
                    .font(.caption)
                    .foregroundStyle(Color.warningOrange)
            }
        }
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconCircle(systemName: "storefront.fill", size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Store Preference").font(.body)
                    Text("Preferred purchase spot").font(.caption).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Picker("Store", selection: $viewModel.storePreference) {
                    Text("Nearby").tag("Nearby")
                    Text("Supermarket").tag("Supermarket")
                    Text("Any").tag("Any")
                }
                .pickerStyle(.menu)
                .tint(.brandPrimary)
            }
            .padding(14)
            RowDivider()
            SettingsToggleRow(icon: "person.2.fill", title: "Destination List",
                              subtitle: viewModel.isFamily ? "\(store.household?.name ?? "Family") List (Synced)" : "My List (private)",
                              isOn: $viewModel.isFamily)
            RowDivider()
            SettingsToggleRow(icon: "exclamationmark.circle.fill", iconColor: .warningOrange,
                              title: "Urgent", subtitle: "Can bypass Quiet Hours for family alerts",
                              isOn: $viewModel.isUrgent)
            RowDivider()
            HStack(spacing: 12) {
                IconCircle(systemName: "dollarsign.circle.fill", size: 34)
                Text("Estimated price").font(.body)
                Spacer()
                TextField(AppFormat.money(PriceGuide.estimate(for: viewModel.category)), text: $viewModel.priceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
            .padding(14)
            RowDivider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("NOTE OR PREFERENCE", systemImage: "text.alignleft")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("Optional").font(.caption).foregroundStyle(Color.textTertiary)
                }
                TextField("e.g. Get unsweetened if available", text: $viewModel.note, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(Color.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(14)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: AppLayout.cardRadius).stroke(Color.separatorLine))
    }
}
