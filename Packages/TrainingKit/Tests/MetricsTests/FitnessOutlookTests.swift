import Testing
import TrainingCore
@testable import Metrics

private let today = Day(year: 2026, month: 11, day: 9)

private func constantLoad(_ value: Double, days: Int) -> [Day: Double] {
    var result: [Day: Double] = [:]
    for offset in 0..<days { result[today.adding(days: -offset)] = value }
    return result
}

@Test func taperRaisesFormOnRaceDay() throws {
    let raceDay = today.adding(days: 30)
    let outlook = fitnessOutlook(dailyLoad: constantLoad(60, days: 120), today: today, raceDay: raceDay)
    let todayForm = try #require(outlook.history.last?.form)
    let raceForm = try #require(outlook.raceDayForm)
    #expect(raceForm > todayForm)
    #expect(outlook.projection.last?.day == raceDay)
    let peak = try #require(outlook.peakFitness)
    let finalFitness = try #require(outlook.projection.last?.fitness)
    #expect(peak > finalFitness)
}

@Test func noRaceProjectsThirtyDaysFlat() {
    let outlook = fitnessOutlook(dailyLoad: constantLoad(60, days: 120), today: today, raceDay: nil)
    #expect(outlook.projection.count == 30)
    #expect(outlook.projection.first?.day == today.adding(days: 1))
    #expect(outlook.raceDayForm == nil)
    #expect(outlook.history.count == 120)
    #expect(outlook.history.last?.day == today)
}
