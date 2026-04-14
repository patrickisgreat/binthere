import SwiftUI
import SwiftData

struct ZonesGridView: View {
    @Query(sort: \Zone.name) private var zones: [Zone]
    @State private var showingAddZone = false
    @State private var showingHomeKitImport = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            if zones.isEmpty {
                BrandedEmptyState.noZones
                    .padding(.top, Theme.Spacing.xxl)
            } else {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(zones) { zone in
                        NavigationLink(value: zone) {
                            ZoneCard(zone: zone)
                                .animatedAppearance()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .navigationTitle("Zones")
        .navigationDestination(for: Zone.self) { zone in
            ZoneDetailView(zone: zone)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: { showingAddZone = true }) {
                        Label("New Zone", systemImage: "plus")
                    }
                    Button(action: { showingHomeKitImport = true }) {
                        Label("Import from Home", systemImage: "house")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddZone) {
            AddZoneSheet()
                .cardPresentation()
        }
        .sheet(isPresented: $showingHomeKitImport) {
            HomeKitImportSheet()
        }
    }
}

private struct ZoneCard: View {
    let zone: Zone

    private var zoneColor: Color {
        zone.color.isEmpty ? .gray : ColorPalette.from(zone.color).color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZoneIcon(iconName: zone.icon, colorName: zone.color, size: 28)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Text("\(zone.bins.count)")
                    .font(Theme.Typography.title)
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Label("\(zone.bins.count) bins", systemImage: "archivebox")
                    Label("\(zone.totalItemCount) items", systemImage: "cube.box")
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(.white.opacity(0.8))

                if zone.totalValue > 0 {
                    Text(CurrencyFormatter.format(zone.totalValue))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if !zone.locationDescription.isEmpty {
                Text(zone.locationDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(zoneColor.gradient)
        )
        .shadow(color: zoneColor.opacity(0.3), radius: 8, y: 4)
    }
}
