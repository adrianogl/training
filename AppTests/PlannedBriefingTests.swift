import FITReader
import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct PlannedBriefingTests {
    private static let today = Day(iso: "2026-11-13")!

    private static let long = PlannedWorkout(
        id: 1, day: "2026-11-14", title: "Corrida Longo sáb 14/11", estimatedSeconds: 5_400, estimatedMeters: 20_000,
        steps: [PlannedStep(kind: .other, meters: 20_000, target: .pace(fastest: 264, slowest: 280))]
    )

    private static let intervals = PlannedWorkout(
        id: 2, day: "2026-11-17", title: "Intervalado ter 17/11", estimatedSeconds: 3_300, estimatedMeters: 12_000,
        steps: [
            PlannedStep(kind: .warmup, seconds: 900),
            PlannedStep(kind: .other, repeats: 9, children: [
                PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 211, slowest: 224)),
                PlannedStep(kind: .recovery, seconds: 120),
            ]),
            PlannedStep(kind: .cooldown, seconds: 600),
        ]
    )

    private static let similar = [
        SimilarRun(day: Day(iso: "2026-11-08")!, kilometers: 18, paceSecondsPerKm: 278, averageHeartRate: 162, maxHeartRate: 176, aerobicEffect: 3.8, load: 205, fadeSecondsPerKm: 9),
        SimilarRun(day: Day(iso: "2026-11-01")!, kilometers: 16, paceSecondsPerKm: 281, averageHeartRate: 158, maxHeartRate: 172, aerobicEffect: 3.5, load: 190, fadeSecondsPerKm: 3),
    ]

    private static func input(
        _ plan: PlannedWorkout,
        readiness: Int? = 74,
        weather: [HourlyWeather] = [],
        completed: CompletedCheck? = nil
    ) -> BriefingInput {
        BriefingInput(
            plan: plan, today: today, similar: similar, readiness: readiness,
            weekDoneKm: 31, weekPlannedKm: 51, weekGoalKm: 45, daysSinceHard: 4,
            race: PlannedRaceContext(name: "Meia", days: 45, longestKilometers: 18, longTargetKilometers: 19),
            weather: weather, course: nil, completed: completed
        )
    }

    @Test func classifiesPlans() {
        #expect(PlannedBriefingBuilder.kind(Self.long) == .long)
        #expect(PlannedBriefingBuilder.kind(Self.intervals) == .intervals)
        #expect(PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 14/11") == "corrida longo")
        #expect(PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 07/11") == PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 14/11"))
    }

    @Test func longRunBriefingUsesTargetHistoryAndRace() {
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.long))

        #expect(briefing.stats.map(\.value) == ["20 km", "4:24–4:40", "1h28–1h33", "~198"])
        #expect(briefing.summary.contains("o mais longo do bloco"))
        #expect(briefing.summary.contains("Pela sua prontidão de hoje (74)"))
        #expect(briefing.phases.map(\.when) == ["km 0–2", "km 2–16", "km 16–20"])
        #expect(briefing.phases[1].detail.contains("Mire 4:32/km"))
        #expect(briefing.phases[1].detail.contains("162 bpm"))
        #expect(briefing.expectations.first?.value == "158–162")
        #expect(briefing.attention.map(\.title).contains("Queda de ritmo no fim"))
        #expect(briefing.planB.first?.detail == "Faça 14 km em Z2, a 5:10/km.")
        #expect(briefing.raceNote?.contains("fica cumprido") == true)
        #expect(briefing.carry.contains { $0.hasPrefix("1 gel") })
        #expect(briefing.watchTip == "FC até 162 · gel no km 9")
    }

    @Test func intervalsGetTargetPerRepGroup() {
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.intervals))

        #expect(briefing.reps.map(\.label) == ["1º e 2º", "3º a 6º", "7º a 9º"])
        #expect(briefing.reps.map(\.pace) == ["3:41", "3:38", "3:34"])
        #expect(briefing.reps.first?.heartRate == "até 166")
        #expect(briefing.summary.hasPrefix("Intervalado de 9 × 1000 m."))
        #expect(briefing.planB.first?.detail == "Faça 6 tiros em vez de 9, no mesmo alvo.")
    }

    @Test func heatChangesAttentionTagsAndBestHours() {
        let weather = (5...10).map { HourlyWeather(hour: $0, temperature: 19 + Double($0 - 5) * 2.4, dewPoint: 16) }

        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.long, weather: weather))

        #expect(briefing.attention.first?.title == "Calor e umidade")
        #expect(briefing.tags.contains { $0.text == "26 °C às 8h" })
        #expect(PlannedBriefingBuilder.coolest(weather).map(\.hour) == [5, 6])
        #expect(briefing.bestHoursNote?.hasPrefix("Saindo às 5h") == true)
        #expect(briefing.watchTip == "26° às 8h · saia cedo")
    }

    @Test func lowReadinessLeadsWithWarning() {
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.long, readiness: 42))

        #expect(briefing.attention.first?.title == "Prontidão baixa")
        #expect(briefing.tags.first?.tone == .bad)
    }

    @Test func comparisonChecksPlanAgainstDone() {
        let done = CompletedCheck(kilometers: 20.1, paceSecondsPerKm: 273, averageHeartRate: 163, fadeSecondsPerKm: 6.5)

        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.long, completed: done))

        #expect(briefing.comparison.map(\.ok) == [true, true, true, false])
        #expect(briefing.comparisonNote == "Parte do plano ficou fora do alvo.")
    }

    @Test func courseFinderPrefersFewerLaps() {
        let courses = [
            GarminCourseSummary(id: 1, name: "Lagoa", meters: 9_900, elevationGain: 42),
            GarminCourseSummary(id: 2, name: "Avenida", meters: 5_000, elevationGain: 10),
            GarminCourseSummary(id: 3, name: "Serra", meters: 30_000, elevationGain: 600),
        ]

        let pick = PlannedCourseFinder.best(courses, plannedMeters: 20_000)

        #expect(pick?.course.name == "Lagoa")
        #expect(pick?.laps == 2)
        #expect(PlannedCourseFinder.best(courses, plannedMeters: 50_000) == nil)
    }

    @Test func fadeComparesLastFifthWithMiddleIgnoringStops() {
        var samples = (0...200).map { index -> FITSample in
            let meters = Double(index) * 50
            return FITSample(t: Double(index) * 15, speed: meters <= 8_000 ? 1_000.0 / 300 : 1_000.0 / 310, distance: meters)
        }
        samples += (0..<60).map { FITSample(t: 3_100 + Double($0) * 5, speed: 0.3, distance: 10_000 + Double($0)) }

        let fade = PlannedBriefingLoader.fade(samples)

        #expect(abs((fade ?? 0) - 10) < 0.5)
    }

    @Test func weatherRequestUsesRoundedCoordinateAndParsesMorning() throws {
        let url = try #require(PlannedWeather.url(day: Day(iso: "2026-11-14")!, coordinate: Coordinate(lat: -19.8573, lon: -43.9712)))
        let query = url.query ?? ""
        #expect(query.contains("latitude=-19.9"))
        #expect(query.contains("longitude=-44.0"))
        #expect(query.contains("start_date=2026-11-14"))

        let json = """
        {"hourly":{"time":["2026-11-14T04:00","2026-11-14T05:00","2026-11-14T06:00","2026-11-14T11:00"],
        "temperature_2m":[18.2,19.1,null,30.5],"dew_point_2m":[15.0,15.4,15.8,16.0]}}
        """
        let hours = PlannedWeather.parse(Data(json.utf8))
        #expect(hours == [HourlyWeather(hour: 5, temperature: 19.1, dewPoint: 15.4)])
    }
}
