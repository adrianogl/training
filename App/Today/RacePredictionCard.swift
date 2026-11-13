import Charts
import SwiftUI
import WorkoutAnalysis

struct RacePredictionCard: View {
    let content: RacePredictionContent
    var horizon: Binding<ProjectionHorizon>?

    var body: some View {
        let race = content.race
        VStack(alignment: .leading, spacing: 10) {
            header
            if let horizon {
                Picker(EvolutionConstants.horizonLabel, selection: horizon) {
                    ForEach(HorizonOption.all, id: \.horizon) { Text($0.title).tag($0.horizon) }
                }
                .pickerStyle(.segmented)
            }
            if race.today == nil {
                Text(TodayConstants.predictionEmpty)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.dim)
            } else {
                HStack(alignment: .top) {
                    time(TodayConstants.predictionToday, race.today, BrandColors.text)
                    if content.raceDay != nil {
                        time(TodayConstants.predictionRaceDay, race.raceDay?.mid, BrandColors.race)
                    }
                }
                if let support = supportLine {
                    Text(support).font(.caption).foregroundStyle(BrandColors.dim)
                }
                chart
                if let sentence = content.goalSentence {
                    Text(sentence)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.text)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BrandColors.raceGlow, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .brandCard(fillsHeight: true)
    }

    private var header: some View {
        HStack(spacing: 6) {
            SectionLabel("\(TodayConstants.predictionTitle) · \(content.title)")
                .padding(.top, 0)
                .padding(.bottom, 0)
            if let countdown = content.countdownText {
                Text("· \(countdown)")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.race)
            }
        }
    }

    private var supportLine: String? {
        let race = content.race
        var parts: [String] = []
        if let point = race.raceDay {
            parts.append("\(TodayConstants.predictionBandPrefix) \(WorkoutFormat.clock(point.low))–\(WorkoutFormat.clock(point.high))")
        }
        if let yearAgo = race.yearAgo {
            parts.append("\(TodayConstants.predictionYearAgoPrefix): \(WorkoutFormat.clock(yearAgo))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var chart: some View {
        let race = content.race
        return Chart {
            ForEach(content.band) { point in
                AreaMark(x: .value("Dia", point.date), yStart: .value("Mínimo", point.low), yEnd: .value("Máximo", point.high))
                    .foregroundStyle(BrandColors.race.opacity(0.14))
            }
            ForEach(content.lines) { line in
                ForEach(line.points) { point in
                    LineMark(x: .value("Dia", point.date), y: .value("Previsão", point.value), series: .value("Série", line.name))
                        .foregroundStyle(line.colorKey == .prediction ? BrandColors.text : BrandColors.race)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: line.dashed ? [5, 4] : []))
                }
            }
            if let goal = race.goalSeconds {
                RuleMark(y: .value("Meta", goal))
                    .foregroundStyle(BrandColors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(TodayConstants.goalPrefix) \(TodayText.goalClock(goal))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BrandColors.accent)
                    }
            }
            if let raceDay = content.raceDay {
                RuleMark(x: .value("Prova", raceDay.chartDate))
                    .foregroundStyle(BrandColors.race.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                if let point = race.raceDay {
                    PointMark(x: .value("Prova", raceDay.chartDate), y: .value("Previsão", point.mid))
                        .foregroundStyle(BrandColors.race)
                        .symbolSize(70)
                }
            }
            if let today = race.today {
                PointMark(x: .value("Hoje", content.today.chartDate), y: .value("Previsão", today))
                    .foregroundStyle(BrandColors.text)
                    .symbolSize(40)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false, reversed: true))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(BrandColors.line)
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(TodayText.goalClock(seconds)).font(.caption2).foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .frame(height: TodayConstants.predictionChartHeight)
    }

    private func time(_ label: String, _ seconds: Double?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption).foregroundStyle(color == BrandColors.text ? BrandColors.dim : color)
            Text(seconds.map(WorkoutFormat.clock) ?? "—").font(BrandFonts.number(30)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
