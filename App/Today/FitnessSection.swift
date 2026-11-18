import Charts
import SwiftUI

struct FitnessSection: View {
    let model: TodayModel

    var body: some View {
        let fitness = model.summary.fitness
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(TodayConstants.outlookFitnessTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Spacer()
                if let form = fitness.raceDayForm {
                    Text(String(format: TodayConstants.outlookFitnessFormat, TodayText.signed(form)))
                        .font(BrandFonts.number(15))
                        .foregroundStyle(BrandColors.accent)
                }
            }
            if fitness.history.isEmpty {
                Text(TodayConstants.fitnessEmpty)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.dim)
            } else {
                HStack(alignment: .top) {
                    stat(fitness.history.last.map { TodayText.decimal($0.fitness, fractionDigits: 0) }, TodayConstants.fitnessNow, BrandColors.fitness)
                    stat(fitness.peakFitness.map { TodayText.decimal($0, fractionDigits: 0) }, TodayConstants.fitnessPeak, BrandColors.fitness)
                }
                chart
                HStack(spacing: 14) {
                    legend(TodayConstants.fitnessLegendFitness, BrandColors.fitness)
                    legend(TodayConstants.fitnessLegendForm, BrandColors.form)
                    legend(TodayConstants.fitnessLegendRace, BrandColors.race)
                    Text(TodayConstants.fitnessLegendProjection)
                }
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
            }
        }
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

    private func legend(_ label: String, _ color: Color) -> some View {
        DSLegendItem(text: label, color: color)
    }

    private func stat(_ value: String?, _ label: String, _ color: Color) -> some View {
        DSStat(value: value, label: label, color: color)
    }
}
