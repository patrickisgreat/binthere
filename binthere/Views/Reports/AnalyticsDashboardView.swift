import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @Query(sort: \Zone.name) private var zones: [Zone]
    @Query(sort: \Bin.code) private var bins: [Bin]
    @Query private var items: [Item]
    @Query private var checkoutRecords: [CheckoutRecord]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCards
                valueByZoneChart
                itemsByZoneChart
                checkoutActivityChart
                mostCheckedOutChart
            }
            .padding()
        }
        .navigationTitle("Analytics")
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(title: "Bins", value: "\(bins.count)", icon: "archivebox", color: .blue)
            SummaryCard(title: "Items", value: "\(items.count)", icon: "cube.box", color: .purple)
            SummaryCard(title: "Zones", value: "\(zones.count)", icon: "square.grid.2x2", color: .green)
            SummaryCard(
                title: "Total Value",
                value: CurrencyFormatter.format(items.compactMap(\.value).reduce(0, +)),
                icon: "dollarsign.circle",
                color: .orange
            )
            SummaryCard(
                title: "Checked Out",
                value: "\(items.filter(\.isCheckedOut).count)",
                icon: "arrow.right.circle",
                color: .red
            )
            SummaryCard(
                title: "Valued Items",
                value: "\(items.filter { $0.value != nil }.count)",
                icon: "tag",
                color: .teal
            )
        }
    }

    // MARK: - Value by Zone

    private var valueByZoneChart: some View {
        ChartSection(title: "Value by Zone") {
            let data = zones.map { (name: $0.name, value: $0.totalValue, color: $0.color) }
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }

            if data.isEmpty {
                emptyChart("No valued items yet")
            } else {
                Chart(data, id: \.name) { item in
                    BarMark(
                        x: .value("Value", item.value),
                        y: .value("Zone", item.name)
                    )
                    .foregroundStyle(ColorPalette.from(item.color).color)
                    .annotation(position: .trailing) {
                        Text(CurrencyFormatter.format(item.value))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(max(data.count, 1)) * 44)
            }
        }
    }

    // MARK: - Items by Zone

    private var itemsByZoneChart: some View {
        ChartSection(title: "Items per Zone") {
            let data = zones.map { (name: $0.name, itemCount: $0.totalItemCount, color: $0.color) }
                .filter { $0.itemCount > 0 }
                .sorted { $0.itemCount > $1.itemCount }

            if data.isEmpty {
                emptyChart("No items in zones yet")
            } else {
                Chart(data, id: \.name) { item in
                    SectorMark(
                        angle: .value("Items", item.itemCount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(ColorPalette.from(item.color).color)
                    .annotation(position: .overlay) {
                        Text("\(item.itemCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 200)

                // Legend
                FlowLayout(spacing: 8) {
                    ForEach(data, id: \.name) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ColorPalette.from(item.color).color)
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Checkout Activity

    private var checkoutActivityChart: some View {
        ChartSection(title: "Checkout Activity (12 weeks)") {
            let calendar = Calendar.current
            let now = Date()
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
                return AnyView(emptyChart("No data"))
            }

            let recentCheckouts = checkoutRecords.filter { $0.checkedOutAt >= threeMonthsAgo }

            if recentCheckouts.isEmpty {
                return AnyView(emptyChart("No checkouts in the last 12 weeks"))
            }

            let grouped = Dictionary(grouping: recentCheckouts) { record -> Date in
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.checkedOutAt)
                return calendar.date(from: components) ?? record.checkedOutAt
            }

            let weeklyData = grouped.map { (week: $0.key, count: $0.value.count) }
                .sorted { $0.week < $1.week }

            return AnyView(
                Chart(weeklyData, id: \.week) { item in
                    LineMark(
                        x: .value("Week", item.week),
                        y: .value("Checkouts", item.count)
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Week", item.week),
                        y: .value("Checkouts", item.count)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Week", item.week),
                        y: .value("Checkouts", item.count)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
            )
        }
    }

    // MARK: - Most Checked Out

    private var mostCheckedOutChart: some View {
        ChartSection(title: "Most Checked Out Items") {
            let itemCounts = Dictionary(grouping: checkoutRecords) { $0.item?.name ?? "Unknown" }
                .map { (name: $0.key, count: $0.value.count) }
                .sorted { $0.count > $1.count }
                .prefix(10)

            if itemCounts.isEmpty {
                emptyChart("No checkout history yet")
            } else {
                Chart(Array(itemCounts), id: \.name) { item in
                    BarMark(
                        x: .value("Checkouts", item.count),
                        y: .value("Item", item.name)
                    )
                    .foregroundStyle(.purple.gradient)
                }
                .frame(height: CGFloat(max(itemCounts.count, 1)) * 34)
            }
        }
    }

    // MARK: - Helpers

    private func emptyChart(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ChartSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
