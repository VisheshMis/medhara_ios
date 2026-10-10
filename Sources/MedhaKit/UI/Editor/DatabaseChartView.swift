import SwiftUI
import Charts

public struct DatabaseChartView: View {
    @ObservedObject public var store: BlockStore
    public let database: NotionDatabase

    @State private var selectedChartType: DatabaseChartType = .verticalBar
    @State private var selectedGroupPropId: String = ""
    @State private var selectedMetricPropId: String = ""

    public init(store: BlockStore, database: NotionDatabase) {
        self.store = store
        self.database = database
    }

    private var properties: [DatabaseProperty] {
        store.activeDatabaseProperties
    }

    private var categoricalProperties: [DatabaseProperty] {
        properties.filter { $0.type == .status || $0.type == .select || $0.type == .title || $0.type == .richText }
    }

    private var numericProperties: [DatabaseProperty] {
        properties.filter { $0.type == .number }
    }

    private var activeGroupPropertyId: String {
        if !selectedGroupPropId.isEmpty { return selectedGroupPropId }
        return categoricalProperties.first?.id ?? properties.first?.id ?? ""
    }

    private var chartData: [ChartDataPoint] {
        guard !activeGroupPropertyId.isEmpty else { return [] }
        return store.databaseService.computeAnalyticsData(
            databaseId: database.id,
            groupByPropertyId: activeGroupPropertyId,
            metricPropertyId: selectedMetricPropId.isEmpty ? nil : selectedMetricPropId,
            aggregation: selectedMetricPropId.isEmpty ? .count : .sum
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Analytics Controls Bar
            HStack(spacing: 12) {
                // Chart Type Picker
                Picker("Layout", selection: $selectedChartType) {
                    ForEach(DatabaseChartType.allCases, id: \.self) { type in
                        HStack(spacing: 4) {
                            Image(systemName: type.systemIcon)
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 160)

                // Group-by Property Picker
                if !categoricalProperties.isEmpty {
                    Picker("Group By", selection: $selectedGroupPropId) {
                        ForEach(categoricalProperties) { prop in
                            Text(prop.name).tag(prop.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 160)
                }

                // Metric Property Picker
                if !numericProperties.isEmpty {
                    Picker("Metric", selection: $selectedMetricPropId) {
                        Text("Record Count").tag("")
                        ForEach(numericProperties) { prop in
                            Text("Sum of \(prop.name)").tag(prop.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Divider()

            // Chart Render Canvas
            if chartData.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 32))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                        Text("No analytics data available")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MedhaTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, 36)
                    Spacer()
                }
            } else {
                VStack {
                    switch selectedChartType {
                    case .verticalBar:
                        verticalBarChart
                    case .horizontalBar:
                        horizontalBarChart
                    case .line:
                        lineTrendChart
                    case .sector:
                        sectorDonutChart
                    case .kpi:
                        kpiCardView
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Swift Charts Renderers
    private var verticalBarChart: some View {
        Chart(chartData) { point in
            BarMark(
                x: .value("Category", point.category),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Category", point.category))
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
    }

    private var horizontalBarChart: some View {
        Chart(chartData) { point in
            BarMark(
                x: .value("Value", point.value),
                y: .value("Category", point.category)
            )
            .foregroundStyle(by: .value("Category", point.category))
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
    }

    private var lineTrendChart: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Category", point.category),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .symbol(Circle())
            .foregroundStyle(MedhaTheme.Colors.accent)

            AreaMark(
                x: .value("Category", point.category),
                y: .value("Value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [MedhaTheme.Colors.accent.opacity(0.3), MedhaTheme.Colors.accent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var sectorDonutChart: some View {
        Chart(chartData) { point in
            SectorMark(
                angle: .value("Value", point.value),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(by: .value("Category", point.category))
        }
    }

    private var kpiCardView: some View {
        let totalVal = chartData.reduce(0.0) { $0 + $1.value }
        let topCategory = chartData.max(by: { $0.value < $1.value })?.category ?? "None"

        return HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL AGGREGATE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Text(String(format: "%.1f", totalVal))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(MedhaTheme.Colors.accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text("TOP CATEGORY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Text(topCategory)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(.vertical, 16)
    }
}
