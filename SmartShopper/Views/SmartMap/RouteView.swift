//
//  RouteView.swift
//  SmartShopper
//
//  driving route to the shop with the next turn instruction.
//  The route line, steps, distance and ETA come from MKDirections (real data).
//  If Apple Maps has no directions for the area, we show distance + an estimate instead.
//

import SwiftUI
import MapKit

struct RouteView: View {
    let store: NearbyStore

    @EnvironmentObject private var smartMap: SmartMapViewModel
    @EnvironmentObject private var data: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .userLocation(followsHeading: true, fallback: MapDefaults.colombo)
    @State private var showInStore = false

    // Items from the CURRENT shopping list this shop can supply.
    // Worked out live, so it is right even if the list changed after the shop search.
    private var itemsForThisShop: [ShoppingItem] {
        StoreMatcher.matchedItems(for: store.type, in: data.allRemainingItems)
    }

    private var route: MKRoute? {
        smartMap.selectedStore?.id == store.id ? smartMap.route : nil
    }

    /// First real instruction (the first step is often empty "start").
    private var nextStep: MKRoute.Step? {
        route?.steps.first { !$0.instructions.isEmpty }
    }

    private var stepAfter: MKRoute.Step? {
        guard let route, let next = nextStep, let index = route.steps.firstIndex(of: next) else { return nil }
        let rest = route.steps.dropFirst(index + 1)
        return rest.first { !$0.instructions.isEmpty }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                UserAnnotation()
                Annotation(store.name, coordinate: store.coordinate) {
                    StorePin(type: store.type, isSelected: true)
                }
                if let route {
                    MapPolyline(route)
                        .stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                } else if smartMap.routeUnavailable, let here = smartMap.location.lastLocation?.coordinate {
                    // No road directions here - draw a dashed straight line to the shop instead
                    MapPolyline(coordinates: [here, store.coordinate])
                        .stroke(Color.brandPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [8, 8]))
                }
            }
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                instructionBanner
                if let stepAfter {
                    Label("Then: \(stepAfter.instructions)", systemImage: "arrow.right")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) { bottomCard }
        .fullScreenCover(isPresented: $showInStore) {
            InStoreModeView(items: itemsForThisShop, storeName: store.name, storeArea: store.address)
        }
        .task {
            if route == nil {
                await smartMap.select(store)
            }
        }
    }

    private var instructionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.title)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                if let nextStep {
                    Text("In \(AppFormat.distance(nextStep.distance))")
                        .font(.title2.weight(.bold))
                    Text(nextStep.instructions)
                        .font(.headline)
                        .lineLimit(2)
                } else if route == nil && smartMap.routeUnavailable {
                    Text("\(AppFormat.distance(store.distanceMeters)) away")
                        .font(.title2.weight(.bold))
                    Text("Road directions aren't available here")
                        .font(.headline)
                } else if route == nil {
                    Text("Calculating route...")
                        .font(.headline)
                } else {
                    Text("Head to \(store.name)")
                        .font(.headline)
                }
                Text("Then arrive at \(store.name)")
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.heroGreen)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Pill(text: "Pitstop Ready", background: .brandMint)
            }
            Text("\(store.type.title) • \(smartMap.detourText)")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 10) {
                infoChip(icon: "bag.fill", title: "Reserved", value: "\(itemsForThisShop.count) list items")
                infoChip(icon: "square.grid.2x2.fill", title: "In-store", value: "Aisle order ready")
            }

            HStack(alignment: .firstTextBaseline) {
                if let route {
                    Text("\(max(1, Int((route.expectedTravelTime / 60).rounded()))) min")
                        .font(.title.weight(.bold))
                    Text(AppFormat.distance(route.distance))
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                } else if smartMap.routeUnavailable {
                    Text(smartMap.detourText)
                        .font(.title3.weight(.bold))
                    Text(AppFormat.distance(store.distanceMeters))
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                } else {
                    ProgressView()
                }
                Spacer()
                Button("Open in Apple Maps") { smartMap.openInMaps(store) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.dangerRed)
                        .frame(width: 52, height: 52)
                        .background(Color.dangerSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("End route")
                PrimaryButton(title: "Start In-Store Mode", trailingArrow: true,
                              isEnabled: !itemsForThisShop.isEmpty) {
                    showInStore = true
                }
            }
        }
        .padding(18)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
        .padding(.horizontal, 10)
    }

    private func infoChip(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(Color.textSecondary)
                Text(value).font(.caption.weight(.semibold)).foregroundStyle(Color.textPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
