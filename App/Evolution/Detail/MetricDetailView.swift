import Charts
import SwiftUI

struct MetricDetailView: View {
    @State private var model: MetricDetailModel

    init(model: MetricDetailModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                periodPicker
                if model.series == nil {
                    BrandLoader(size: .regular).frame(maxWidth: .infinity).padding(.top, 40)
                } else if !model.hasData {
                    Text(EvolutionConstants.detailNoData)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                } else {
                    content
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private var periodPicker: some View {
        Picker(EvolutionConstants.periodLabel, selection: Binding(
            get: { model.period },
            set: { period in Task { await model.select(period: period) } }
        )) {
            ForEach(MetricPeriodOption.all, id: \.period) { option in
                Text(option.title).tag(option.period)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        statsCard
        section(EvolutionConstants.detailChartTitle)
        chartCard
        if !model.monthly.isEmpty {
            section(EvolutionConstants.detailMonthly)
            monthlyCard
        }
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - 12)
            .padding(.bottom, DSSpacing.sectionBottom - 12)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ForEach(model.statCells) { cell in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(cell.value)
                            .font(BrandFonts.number(cell.title == EvolutionConstants.detailCurrent ? 26 : 20))
                            .foregroundStyle(cell.title == EvolutionConstants.detailCurrent ? BrandColors.accent : BrandColors.text)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text(cell.title).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let change = model.change {
                HStack(spacing: 6) {
                    Text(EvolutionConstants.detailTrend).font(.caption).foregroundStyle(BrandColors.dim)
                    Text(change.text).font(.subheadline.weight(.semibold)).foregroundStyle(EvolutionColors.trend(change.trend))
                    Text("no período").font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            if let raceDay = model.raceDayText {
                HStack(spacing: 6) {
                    Text(EvolutionConstants.detailRaceDay).font(.caption).foregroundStyle(BrandColors.dim)
                    Text(raceDay).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
            }
            if let lastYear = model.lastYearText {
                (Text(EvolutionConstants.detailLastYear + ": ").foregroundStyle(BrandColors.dim) + Text(lastYear).foregroundStyle(BrandColors.text))
                    .font(.caption)
            }
            if let reading = model.reading {
                Divider().overlay(BrandColors.line)
                Text(reading).font(.subheadline).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let chart = model.chart {
                MetricChart(data: chart, style: .full)
            }
            DSFlowLayout(spacing: DSSpacing.s3) {
                DSLegendItem(text: EvolutionConstants.averageLabel, color: BrandColors.text)
                DSLegendItem(text: EvolutionConstants.projectionLabel, color: BrandColors.accent, mark: .dashed)
                DSLegendItem(text: EvolutionConstants.lastYearLabel, color: BrandColors.dim)
                if !(model.chart?.markers.isEmpty ?? true) {
                    DSLegendItem(text: EvolutionConstants.raceLegend, color: BrandColors.race)
                }
            }
            if let markers = model.chart?.markers, !markers.isEmpty {
                DSFlowLayout(spacing: 6) {
                    ForEach(markers) { marker in
                        Text(String(format: EvolutionConstants.raceMarkerFormat, marker.name, marker.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits).locale(WorkoutConstants.locale))))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BrandColors.race)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(BrandColors.race.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .opacity(model.isLoading ? 0.5 : 1)
    }

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(model.monthly) { month in
                BarMark(x: .value("Mês", month.date, unit: .month), y: .value("Média", month.value))
                    .foregroundStyle(BrandColors.fitness.opacity(0.8))
                    .annotation(position: .top) {
                        Text(EvolutionText.value(month.value, EvolutionConstants.metricFormats[model.kind]))
                            .font(.system(size: 8))
                            .foregroundStyle(BrandColors.dim)
                    }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow).locale(WorkoutConstants.locale))
                }
            }
            .frame(height: EvolutionConstants.monthlyChartHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
