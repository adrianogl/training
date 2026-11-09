import Charts
import SwiftUI

struct FitnessCard: View {
    let model: TodayModel

    var body: some View {
        let fitness = model.summary.fitness
        let hasRace = model.raceDay != nil
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(hasRace ? TodayConstants.fitnessTitleWithRace : TodayConstants.fitnessTitleWithoutRace)
                .padding(.top, 0)
                .padding(.bottom, 0)
            if fitness.history.isEmpty {
                Text(TodayConstants.fitnessEmpty)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.dim)
            } else {
                HStack(alignment: .top) {
                    stat(fitness.history.last.map { TodayText.decimal($0.fitness, fractionDigits: 0) }, TodayConstants.fitnessNow, BrandColors.fitness)
                    stat(fitness.peakFitness.map { TodayText.decimal($0, fractionDigits: 0) }, TodayConstants.fitnessPeak, BrandColors.fitness)
                    if hasRace {
                        stat(fitness.raceDayForm.map { TodayText.signed($0) }, TodayConstants.fitnessRaceForm, BrandColors.accent)
                    }
                }
                chart
                Text(TodayConstants.fitnessLegend)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .glassCard()
    }

    private var chart: some View {
        Chart {
            ForEach(model.fitnessLines) { line in
                ForEach(line.points) { point in
                    LineMark(x: .value("Dia", point.date), y: .value("Valor", point.value), series: .value("Série", line.name))
                        .foregroundStyle(line.colorKey == .fitness ? BrandColors.fitness : BrandColors.form)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: line.dashed ? [5, 4] : []))
                }
            }
            RuleMark(x: .value("Hoje", model.today.chartDate))
                .foregroundStyle(BrandColors.marker)
            if let raceDay = model.raceDay {
                RuleMark(x: .value("Prova", raceDay.chartDate))
                    .foregroundStyle(BrandColors.race.opacity(0.55))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: TodayConstants.chartHeight)
    }

    private func stat(_ value: String?, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value ?? "—").font(BrandFonts.number(30)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
