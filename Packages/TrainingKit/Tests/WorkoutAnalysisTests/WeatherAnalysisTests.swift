import FITReader
import Testing
import TrainingCore
@testable import WorkoutAnalysis

private let target = PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 10000), target: .speed(low: 3.9, high: 4.1))
private let humid = WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21))
private let warm = WeatherAdjustment.effect(RunWeather(temperature: 22, dewPoint: 12))
private let freezing = WeatherAdjustment.effect(RunWeather(temperature: -5, dewPoint: nil))

private func laps(_ paces: [Double], heartRates: [Int]) -> [LapSummary] {
    var offset = 0.0
    return paces.enumerated().map { index, pace in
        defer { offset += pace }
        return LapSummary(stepIndex: 1, intensity: .active, startOffset: offset, timerSeconds: pace, distance: 1000, avgSpeed: 1000 / pace, avgHeartRate: heartRates[index])
    }
}

private func run(
    _ kind: BlockKind = .active,
    speed: Double,
    status: BlockStatus,
    prescribed: PrescribedStep? = target,
    heartRate: Int = 150,
    zone: Int = 2,
    laps: [LapSummary] = []
) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind, ordinal: 1, label: kind == .warmup ? "Aquecimento" : "Bloco 1", prescribed: prescribed, laps: laps,
        seconds: 10000 / speed, distance: 10000, avgSpeed: speed, avgHeartRate: heartRate, maxHeartRate: heartRate + 10,
        dominantZone: zone, status: status
    )
}

@Test func slowerBlockInsideTargetInMildClimateIsInTarget() {
    let blocks = adjustForWeather([run(speed: 3.75, status: .slower)], effect: humid)

    #expect(blocks[0].status == .inTarget)
    #expect(blocks[0].weatherRescued == true)
    let assessment = assess(blocks, context: AssessmentContext(weather: humid))
    #expect(assessment.negatives.isEmpty)
    let finding = assessment.positives.first { $0.kind == .weatherSlower }
    #expect(finding?.facts[FindingFact.temperature] == 28)
    #expect(abs((finding?.facts[FindingFact.mildPace] ?? 0) - 1000 / 3.75 / (1 + (humid?.paceFactor ?? 0))) < 0.01)
    #expect(assessment.positives.contains { $0.kind == .blockInTarget })
}

@Test func tooSlowEvenInMildClimateStaysOffTarget() {
    let blocks = adjustForWeather([run(speed: 3.5, status: .slower)], effect: humid)

    #expect(blocks[0].status == .slower)
    #expect(assess(blocks, context: AssessmentContext(weather: humid)).negatives.contains { $0.kind == .blockOffTarget })
}

@Test func fasterThanTargetIsNotRescued() {
    let blocks = adjustForWeather([run(speed: 4.3, status: .faster)], effect: humid)

    #expect(blocks[0].status == .faster)
    #expect(blocks[0].weatherRescued == nil)
}

@Test func noWeatherKeepsBlocksAsTheyAre() {
    let blocks = [run(speed: 3.75, status: .slower)]
    #expect(adjustForWeather(blocks, effect: nil) == blocks)
    #expect(adjustForWeather(blocks, effect: warm.map { WeatherEffect(weather: $0.weather, stress: .mild, paceFactor: 0) }) == blocks)
}

@Test func coldRescuesSlowerBlock() {
    let blocks = adjustForWeather([run(speed: 3.87, status: .slower)], effect: freezing)

    let finding = assess(blocks, context: AssessmentContext(weather: freezing)).positives.first { $0.kind == .weatherSlower }
    #expect(finding?.facts[FindingFact.cold] == 1)
}

@Test func driftInHumidHeatIsExpected() {
    let drifting = laps(Array(repeating: 250, count: 6), heartRates: [150, 152, 155, 158, 161, 163])
    let blocks = [run(speed: 4, status: .noTarget, prescribed: nil, laps: drifting)]

    let hot = assess(blocks, context: AssessmentContext(weather: humid))
    #expect(hot.positives.first { $0.kind == .cardiacDrift }?.facts[FindingFact.temperature] == 28)
    #expect(!hot.attention.contains { $0.kind == .cardiacDrift })

    let mild = assess(blocks, context: AssessmentContext(weather: warm))
    #expect(mild.attention.contains { $0.kind == .cardiacDrift })

    let cold = assess(blocks, context: AssessmentContext(weather: freezing))
    #expect(cold.attention.contains { $0.kind == .cardiacDrift })
}

@Test func warmupZoneLimitRisesInHeat() {
    let zoneThree = [run(.warmup, speed: 3, status: .noTarget, prescribed: nil, zone: 3)]
    let zoneFour = [run(.warmup, speed: 3, status: .noTarget, prescribed: nil, zone: 4)]

    #expect(!assess(zoneThree, context: AssessmentContext(weather: humid)).attention.contains { $0.kind == .zoneAboveTarget })
    #expect(assess(zoneFour, context: AssessmentContext(weather: humid)).attention.contains { $0.kind == .zoneAboveTarget })
    #expect(assess(zoneThree, context: AssessmentContext(weather: warm)).attention.contains { $0.kind == .zoneAboveTarget })
}

@Test func costComparesInMildClimate() {
    let previous = [WorkoutOccurrence(activityId: 1, day: Day(year: 2026, month: 11, day: 10), blocks: [run(speed: 4.0, status: .inTarget)])]
    let hot = adjustForWeather([run(speed: 3.82, status: .slower)], effect: humid)
    let unadjusted = [run(speed: 3.82, status: .slower)]

    let hotCost = scoreWorkout(blocks: hot, zones: nil, previous: previous)?.items.first { $0.part == .cost }
    let plainCost = scoreWorkout(blocks: unadjusted, zones: nil, previous: previous)?.items.first { $0.part == .cost }
    #expect(hotCost?.reason == nil)
    #expect(plainCost?.reason == .lessEfficient)
}

@Test func heatAlreadyInTargetIsNotDiscountedAgain() {
    let factor = humid?.paceFactor ?? 0
    let blocks = adjustForWeather([run(speed: 3.75, status: .slower)], effect: humid, includedHeat: factor)

    #expect(blocks[0].status == .slower)
    #expect(blocks[0].weatherRescued == nil)
    #expect(blocks[0].weatherFactor == factor)
}

@Test func onlyTheHeatAboveWhatWasIncludedRescues() {
    let factor = humid?.paceFactor ?? 0
    let speed = 3.9 / (1 + factor * 0.6)
    let partly = adjustForWeather([run(speed: speed, status: .slower)], effect: humid, includedHeat: factor * 0.2)
    let mostly = adjustForWeather([run(speed: speed, status: .slower)], effect: humid, includedHeat: factor * 0.8)

    #expect(partly[0].status == .inTarget)
    #expect(partly[0].weatherRescued == true)
    #expect(mostly[0].status == .slower)
}

@Test func includedHeatAboveMeasuredCountsAsZero() {
    let blocks = adjustForWeather([run(speed: 3.85, status: .slower)], effect: humid, includedHeat: 1)

    #expect(blocks[0].status == .slower)
    #expect(blocks[0].weatherFactor == humid?.paceFactor)
}

@Test func includedHeatOnlyTouchesActiveBlocks() {
    let factor = humid?.paceFactor ?? 0
    let warmup = adjustForWeather([run(.warmup, speed: 3.75, status: .slower)], effect: humid, includedHeat: factor)

    #expect(warmup[0].status == .inTarget)
}
