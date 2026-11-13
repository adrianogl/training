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
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
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
        chartCard
        if let reading = model.reading {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(EvolutionConstants.detailReading).padding(.top, 0).padding(.bottom, 0)
                Text(reading).font(.subheadline).foregroundStyle(BrandColors.text)
            }
            .brandCard()
        }
        if !model.monthly.isEmpty { monthlyCard }
        if let lastYear = model.lastYearText {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(EvolutionConstants.detailLastYear).padding(.top, 0).padding(.bottom, 0)
                Text(lastYear).font(.subheadline).foregroundStyle(BrandColors.text)
            }
            .brandCard()
        }
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
        }
        .brandCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let chart = model.chart {
                MetricChart(data: chart, style: .full)
            }
            Text(EvolutionConstants.detailLegend).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
        .opacity(model.isLoading ? 0.5 : 1)
    }

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(EvolutionConstants.detailMonthly).padding(.top, 0).padding(.bottom, 0)
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
        .brandCard()
    }
}
