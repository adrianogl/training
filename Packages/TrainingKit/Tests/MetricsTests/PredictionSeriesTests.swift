import Testing
import TrainingCore
@testable import Metrics

private let start = Day(year: 2026, month: 11, day: 1)

@Test func predictionSeriesSkipsDaysWithoutEfforts() {
    let effort = Effort(distance: 10_000, seconds: 3000, day: start.adding(days: 3), kind: .race)
    let series = predictionSeries(distance: 21_100, efforts: [effort], from: start, to: start.adding(days: 6))
    #expect(series.map(\.0) == (3...6).map { start.adding(days: $0) })
}

@Test func predictionSeriesMatchesPredictOnEachDay() {
    let efforts = [
        Effort(distance: 10_000, seconds: 3000, day: start, kind: .race),
        Effort(distance: 5_000, seconds: 1400, day: start.adding(days: 2), kind: .split5k),
    ]
    let end = start.adding(days: 5)
    let series = predictionSeries(distance: 21_100, efforts: efforts, from: start, to: end)
    #expect(series.count == 6)
    for (day, value) in series {
        #expect(value == predict(distance: 21_100, efforts: efforts, on: day))
    }
}
