import FITReader
import Foundation
import Testing
import TrainingCore
@testable import WorkoutAnalysis

private let target = PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 3000), target: .speed(low: 3.0, high: 3.2))

private func lap(start: Double, seconds: Double, meters: Double) -> LapSummary {
    LapSummary(stepIndex: 1, intensity: .active, startOffset: start, timerSeconds: seconds, distance: meters, avgSpeed: meters / seconds)
}

private func samples(northSeconds: Double, southSeconds: Double, speed: Double = 3.0, cadence: (Double, Double)? = nil, stance: (Double, Double)? = nil) -> [FITSample] {
    let total = northSeconds + southSeconds
    let metersPerDegree = 111_320.0
    var latitude = -23.5
    return stride(from: 0.0, to: total, by: 5).map { t in
        latitude += (t < northSeconds ? 1 : -1) * speed * 5 / metersPerDegree
        let late = t >= total * 2 / 3
        return FITSample(
            t: t, heartRate: 150, speed: speed, distance: t * speed,
            cadence: cadence.map { late ? $0.1 : $0.0 }, stanceTime: stance.map { late ? $0.1 : $0.0 },
            lat: latitude, lon: -46.6
        )
    }
}

@Test func headwindCostsPaceAndTailwindGivesBackHalf() {
    #expect(abs(WeatherAdjustment.windCost(headwind: 4) - 0.04) < 0.0001)
    #expect(abs(WeatherAdjustment.windCost(headwind: -4) + 0.02) < 0.0001)
    #expect(abs(WeatherAdjustment.headwind(windSpeed: 4, windFrom: 0, heading: 0) - 3) < 0.0001)
    #expect(abs(WeatherAdjustment.headwind(windSpeed: 4, windFrom: 0, heading: 180) + 3) < 0.0001)
}

@Test func windIsMeasuredPerBlockFromTheRoute() {
    let wind = RunWeather(temperature: 18, dewPoint: 10, windSpeed: 5, windFrom: 0)
    let blocks = [
        WorkoutBlock(kind: .active, ordinal: 1, label: "Ida", prescribed: target, laps: [lap(start: 0, seconds: 1000, meters: 2950)],
                     seconds: 1000, distance: 2950, avgSpeed: 2.95, avgHeartRate: 150, maxHeartRate: 160, dominantZone: 3, status: .slower),
        WorkoutBlock(kind: .active, ordinal: 2, label: "Volta", prescribed: target, laps: [lap(start: 1000, seconds: 1000, meters: 3100)],
                     seconds: 1000, distance: 3100, avgSpeed: 3.1, avgHeartRate: 150, maxHeartRate: 160, dominantZone: 3, status: .inTarget),
    ]
    let windy = adjustForWeather(applyWind(blocks, samples: samples(northSeconds: 1000, southSeconds: 1000), weather: wind), effect: WeatherAdjustment.effect(wind))

    #expect((windy[0].headwind ?? 0) > 3.5)
    #expect((windy[0].windFactor ?? 0) > 0.03)
    #expect((windy[1].windFactor ?? 0) < 0)
    #expect(windy[0].status == .inTarget)
    #expect(windy[0].weatherRescued == true)
}

@Test func windAgainstListsTheKilometersAgainstTheWind() {
    let wind = RunWeather(temperature: 18, dewPoint: 10, windSpeed: 5, windFrom: 0)
    let rows = (0..<4).map { index in
        WorkoutBlock(kind: .active, ordinal: index + 1, label: "Km \(index + 1)", prescribed: nil, laps: [lap(start: Double(index) * 333, seconds: 333, meters: 1000)],
                     seconds: 333, distance: 1000, avgSpeed: 3.0, avgHeartRate: 150, maxHeartRate: 160, dominantZone: 2, status: .noTarget)
    }
    let windy = applyWind(rows, samples: samples(northSeconds: 666, southSeconds: 666), weather: wind)
    let finding = assess(windy, context: AssessmentContext(weather: WeatherAdjustment.effect(wind))).positives.first { $0.kind == .windAgainst }

    #expect(finding?.facts[FindingFact.fromKilometer] == 1)
    #expect(finding?.facts[FindingFact.toKilometer] == 2)
    #expect(abs((finding?.facts[FindingFact.windSpeed] ?? 0) - 18) < 0.01)
    #expect((finding?.facts[FindingFact.mildPace] ?? 999) < (finding?.facts[FindingFact.pace] ?? 0))
}

@Test func sunAddsHeatAndAdaptationTakesItBack() {
    let shade = WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21))
    let sun = WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21, radiation: 700))
    let adapted = WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21, radiation: 700), hotSessions: 4)

    #expect(abs((sun?.sunBoost ?? 0) - 3.5) < 0.001)
    #expect(sun?.isSunny == true)
    #expect(abs((sun?.paceFactor ?? 0) - 0.0578) < 0.0005)
    #expect((sun?.paceFactor ?? 0) > (shade?.paceFactor ?? 0))
    #expect(abs((adapted?.paceFactor ?? 0) - (sun?.paceFactor ?? 0) * 0.8) < 0.0001)
    #expect(adapted?.hotSessions == 4)
    #expect(WeatherAdjustment.adaptation(hotSessions: 20) == 0.4)
}

@Test func formFadeNeedsCadenceOrStanceToWorsen() {
    let fading = samples(northSeconds: 600, southSeconds: 600, cadence: (172, 167), stance: (238, 251))
    let steady = samples(northSeconds: 600, southSeconds: 600, cadence: (172, 171), stance: (238, 240))
    let blocks = [WorkoutBlock(kind: .active, ordinal: 1, label: "Corrida", prescribed: nil, laps: [], seconds: 1200, distance: 3600,
                               avgSpeed: 3, avgHeartRate: 150, maxHeartRate: 160, dominantZone: 2, status: .noTarget)]

    let finding = assess(blocks, context: AssessmentContext(samples: fading)).attention.first { $0.kind == .runFormFade }
    #expect(finding?.facts[FindingFact.cadenceFrom] == 172)
    #expect(finding?.facts[FindingFact.cadenceTo] == 167)
    #expect(finding?.facts[FindingFact.stanceTo] == 251)
    #expect(!assess(blocks, context: AssessmentContext(samples: steady)).attention.contains { $0.kind == .runFormFade })
    #expect(!assess(blocks, context: AssessmentContext()).attention.contains { $0.kind == .runFormFade })
}

@Test func dayConditionExplainsWithoutChangingTheGroup() {
    let slow = [WorkoutBlock(kind: .active, ordinal: 1, label: "Bloco 1", prescribed: target, laps: [], seconds: 1100, distance: 3000,
                             avgSpeed: 2.7, avgHeartRate: 150, maxHeartRate: 160, dominantZone: 3, status: .slower)]
    let tired = DayCondition(sleepSeconds: 5 * 3600 + 40 * 60, sleepScore: 72, hrvBelowBalanced: false, bodyBattery: 32, previousDay: .threshold)
    let rested = DayCondition(sleepSeconds: 8 * 3600, sleepScore: 85, hrvBelowBalanced: false, bodyBattery: 80)

    let finding = assess(slow, context: AssessmentContext(day: tired)).negatives.first { $0.kind == .blockOffTarget }
    #expect(finding?.facts[FindingFact.sleepSeconds] == 20_400)
    #expect(finding?.facts[FindingFact.bodyBattery] == 32)
    #expect(finding?.facts[FindingFact.previousDay] == 1)
    #expect(finding?.facts[FindingFact.sleepScore] == nil)
    let calm = assess(slow, context: AssessmentContext(day: rested)).negatives.first { $0.kind == .blockOffTarget }
    #expect(calm?.facts[FindingFact.sleepSeconds] == nil)
    #expect(calm?.facts[FindingFact.bodyBattery] == nil)
}
