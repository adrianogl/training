import Insights
import TrainingCore

struct RacePredictionContent {
    let race: RaceOutlook
    let today: Day
    let raceDay: Day?
    let title: String
    let countdownText: String?
    let goalSentence: String?
    let lines: [ChartLine]
    let band: [ChartBandPoint]

    init(race: RaceOutlook, today: Day, countdownDays: Int?, priority: String?, historyDays: Int?, projectionDays: Int? = nil) {
        let raceDay = countdownDays.map { today.adding(days: $0) }
        self.race = race
        self.today = today
        self.raceDay = raceDay
        self.title = race.label
        self.countdownText = TodayText.countdown(days: countdownDays, priority: priority)
        self.goalSentence = TodayText.goalSentence(
            crossing: race.goalCrossing,
            goalSeconds: race.goalSeconds,
            hasPrediction: race.today != nil,
            raceDay: raceDay
        )
        let from = historyDays.map { today.adding(days: -$0) }
        let history = race.series.filter { point in from.map { point.0 >= $0 } ?? true }.map { ChartPoint(date: $0.0.chartDate, value: $0.1) }
        let projection = projectionDays.map { days in race.longProjection.isEmpty ? race.projection : Array(race.longProjection.prefix(days)) } ?? race.projection
        var lines = [ChartLine(name: "Previsão", colorKey: .prediction, dashed: false, points: history)]
        if !projection.isEmpty, let start = race.today {
            let projected = [ChartPoint(date: today.chartDate, value: start)] + projection.map { ChartPoint(date: $0.day.chartDate, value: $0.mid) }
            lines.append(ChartLine(name: "Previsão projetada", colorKey: .projection, dashed: true, points: projected))
        }
        self.lines = lines
        self.band = projection.map { ChartBandPoint(date: $0.day.chartDate, low: $0.low, high: $0.high) }
    }
}
