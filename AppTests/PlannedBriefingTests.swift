import FITReader
import Foundation
import GarminAPI
import Insights
import Storage
import Testing
import TrainingCore
import WorkoutAnalysis
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
        completed: CompletedCheck? = nil,
        goals: [GoalSnapshot] = []
    ) -> BriefingInput {
        BriefingInput(
            plan: plan, today: today, similar: similar, readiness: readiness,
            weekDoneKm: 31, weekPlannedKm: 51, weekGoalKm: 45, daysSinceHard: 4,
            race: PlannedRaceContext(name: "Meia", days: 45, longestKilometers: 18, longTargetKilometers: 19),
            weather: weather, course: nil, completed: completed, goals: goals
        )
    }

    private static func longGoal(runs: [LongRunCheck]) -> GoalSnapshot {
        GoalSnapshot(
            id: UUID(), kind: .continuousLong, distanceKm: 18, targetSeconds: nil, deadline: nil, paceSecondsPerKm: 300,
            progress: .continuousLong(LongGoalProgress(runs: runs, metCount: 0, bestContinuousKm: nil, achievedOn: nil))
        )
    }

    private static func timeGoal(distanceKm: Double, seconds: Double) -> GoalSnapshot {
        GoalSnapshot(
            id: UUID(), kind: .time, distanceKm: distanceKm, targetSeconds: seconds, deadline: nil, paceSecondsPerKm: nil,
            progress: .time(TimeGoalProgress(todaySeconds: nil, gapSeconds: nil, crossing: .noGoal, achievedOn: nil))
        )
    }

    private static func check(_ iso: String, pauses: [RunPause]?) -> LongRunCheck {
        LongRunCheck(activityId: 1, day: Day(iso: iso)!, distanceKm: 18, longestContinuousKm: nil, pauses: pauses, paceSecondsPerKm: 290, met: nil)
    }

    @Test func stridesShowAsOneStepAndDoNotBecomeTheReps() {
        var plan = Self.intervals
        plan.steps.insert(PlannedStep(kind: .other, repeats: 4, children: [
            PlannedStep(kind: .active, meters: 100, target: .pace(fastest: 200, slowest: 206)),
            PlannedStep(kind: .recovery, meters: 100),
        ]), at: 1)
        let briefing = PlannedBriefingBuilder.briefing(Self.input(plan))

        #expect(briefing.phases[1].when == "Strides 4 × 100 m")
        #expect(briefing.phases[1].title == "volta andando até o início · 3:20–3:26/km")
        #expect(briefing.phases[1].detail == TodayConstants.stridesNote)
        #expect(briefing.reps == PlannedBriefingBuilder.briefing(Self.input(Self.intervals)).reps)
        #expect(PlannedBriefingBuilder.paceTarget(plan)?.fast == 211)
    }

    @Test func longGoalPointsToLastPauseOfLatestRun() {
        let goal = Self.longGoal(runs: [
            Self.check("2026-11-01", pauses: [RunPause(startMeters: 4_000, seconds: 20)]),
            Self.check("2026-11-08", pauses: [RunPause(startMeters: 6_000, seconds: 10), RunPause(startMeters: 12_300, seconds: 35)]),
        ])
        let item = PlannedBriefingBuilder.briefing(Self.input(Self.long, goals: [goal])).attention.first { $0.title == "Meta sem pausas" }

        #expect(item?.detail == "No longão de 8 de nov. você parou no km 12,3 por 35 s. Tome água ou gel antes desse km para não parar.")
        #expect(item?.tone == .warn)
    }

    @Test func longGoalSaysWhenLastRunHadNoPauses() {
        let goal = Self.longGoal(runs: [Self.check("2026-11-08", pauses: [])])
        let item = PlannedBriefingBuilder.briefing(Self.input(Self.long, goals: [goal])).attention.first { $0.title == "Meta sem pausas" }

        #expect(item?.detail == "O último longão (8 de nov.) foi sem pausas. Repita o ritmo e a hidratação.")
        #expect(item?.tone == .good)
    }

    @Test func longGoalWithoutHistoryStatesTarget() {
        let goal = Self.longGoal(runs: [Self.check("2026-11-08", pauses: nil)])
        let item = PlannedBriefingBuilder.briefing(Self.input(Self.long, goals: [goal])).attention.first { $0.title == "Meta sem pausas" }

        #expect(item?.detail == "A meta é 18 km sem pausas a 5:00/km. Ainda não há longão com dado de pausas.")
    }

    @Test func longGoalIsIgnoredOutsideLongRuns() {
        let goal = Self.longGoal(runs: [])
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.intervals, goals: [goal]))

        #expect(!briefing.attention.contains { $0.title == "Meta sem pausas" })
    }

    @Test func timeGoalShowsPaceNextToTarget() {
        let goal = Self.timeGoal(distanceKm: 5, seconds: 1_050)
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.intervals, goals: [goal]))

        #expect(briefing.stats.contains(BriefingStat(value: "3:30", label: "pace da meta de 5 km")))
        #expect(briefing.tags.contains(BriefingTag(text: "Alvo 8 s/km mais lento que a meta", tone: .info)))
    }

    @Test func timeGoalOnlyForFiveAndTenKilometers() {
        let goal = Self.timeGoal(distanceKm: 21.1, seconds: 6_000)
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.intervals, goals: [goal]))

        #expect(!briefing.stats.contains { $0.label.hasPrefix("pace da meta") })
    }

    @Test func classifiesPlans() {
        #expect(PlannedBriefingBuilder.kind(Self.long) == .long)
        #expect(PlannedBriefingBuilder.kind(Self.intervals) == .intervals)
        #expect(PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 14/11") == "corrida longo")
        #expect(PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 07/11") == PlannedBriefingBuilder.similarityKey("Corrida Longo sáb 14/11"))
    }

    @Test func longRunBriefingUsesTargetHistoryAndRace() {
        let briefing = PlannedBriefingBuilder.briefing(Self.input(Self.long))

        #expect(briefing.stats.map(\.value) == ["20 km", "4:24–4:40", "1h28–1h34", "~198"])
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
        #expect(briefing.attention.first?.detail == "26 °C às 8h. Saia mais cedo ou aceite 8 s/km mais lento com a mesma FC.")
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

    @Test func todayAfterMorningSuggestsOnlyHoursAhead() {
        let temperatures: [Int: Double] = [5: 18, 6: 17, 7: 17, 8: 19, 9: 21, 10: 23, 11: 25, 12: 26, 13: 27, 14: 28, 15: 28, 16: 27, 17: 25, 18: 23, 19: 21, 20: 20, 21: 19]
        let weather = temperatures.keys.sorted().map { HourlyWeather(hour: $0, temperature: temperatures[$0]!, dewPoint: 16) }
        var input = Self.input(Self.long, weather: weather)
        input.startHour = 12

        let briefing = PlannedBriefingBuilder.briefing(input)

        #expect(briefing.bestHours.map(\.hour) == Array(12...21))
        #expect(PlannedBriefingBuilder.coolest(briefing.bestHours).map(\.hour) == [20, 21])
        #expect(briefing.bestHoursNote == "Daqui pra frente, o mais fresco é sair às 20h, com 20 °C. Sair às 20h em vez das 12h poupa 3 s/km na mesma FC.")
        #expect(briefing.tags.contains { $0.text == "26 °C às 12h" })
        #expect(briefing.hourHeat[12] == 8)
        #expect(briefing.hourHeat[20] == 5)
        #expect(briefing.hourPaces == [BestHourPace(hour: 20, seconds: 277, extra: 5), BestHourPace(hour: 12, seconds: 280, extra: 8)])
    }

    @Test func hourHeatUsesSameOffsetAsDayAdjust() {
        let hour = HourlyWeather(hour: 18, temperature: 27, dewPoint: 20)
        let share = WeatherAdjustment.heatShare(temperature: 27, dewPoint: 20, hotSessions: 2)

        let heat = PlannedHourHeat.seconds([hour], pace: 285, hotSessions: 2)

        #expect(heat[18] == DayAdjust.heatOffset(285, share: share))
    }

    @Test func hourHeatWithoutDewPointKeepsGenericNote() {
        let weather = [12: 26.0, 13: 27, 20: 20, 21: 19].map { HourlyWeather(hour: $0.key, temperature: $0.value, dewPoint: nil) }
        var input = Self.input(Self.long, weather: weather)
        input.startHour = 12

        let briefing = PlannedBriefingBuilder.briefing(input)

        #expect(briefing.hourHeat.isEmpty)
        #expect(briefing.hourPaces.isEmpty)
        #expect(briefing.bestHoursNote?.hasSuffix("conte com 5 a 10 s/km a mais na mesma FC.") == true)
    }

    @Test func coolDayShowsZeroAndNoPaceRows() {
        let weather = (12...21).map { HourlyWeather(hour: $0, temperature: 15, dewPoint: 8) }
        var input = Self.input(Self.long, weather: weather)
        input.startHour = 12

        let briefing = PlannedBriefingBuilder.briefing(input)

        #expect(briefing.hourHeat.values.allSatisfy { $0 == 0 })
        #expect(briefing.hourPaces.isEmpty)
        #expect(briefing.bestHoursNote == "Sem calor no resto do dia: qualquer horário até as 21h funciona.")
    }

    @Test func freeRunShowsSecondsWithoutPaceRows() {
        let free = PlannedWorkout(id: 3, day: "2026-11-14", title: "Rodagem livre", estimatedSeconds: 3_000, estimatedMeters: 10_000, steps: [PlannedStep(kind: .other, meters: 10_000)])
        let temperatures: [Int: Double] = [12: 29, 13: 28, 20: 20, 21: 19]
        var input = Self.input(free, weather: temperatures.map { HourlyWeather(hour: $0.key, temperature: $0.value, dewPoint: 18) })
        input.startHour = 12

        let briefing = PlannedBriefingBuilder.briefing(input)

        #expect((briefing.hourHeat[12] ?? 0) > (briefing.hourHeat[20] ?? 0))
        #expect(briefing.hourPaces.isEmpty)
        #expect(briefing.bestHoursNote?.contains("em vez das 12h") == true)
    }

    @Test func todayAfterLastHourHasNoSuggestion() {
        let weather = (5...21).map { HourlyWeather(hour: $0, temperature: 22, dewPoint: 16) }
        var input = Self.input(Self.long, weather: weather)
        input.startHour = 22

        let briefing = PlannedBriefingBuilder.briefing(input)

        #expect(briefing.bestHours.isEmpty)
        #expect(briefing.bestHoursNote == nil)
    }

    @Test func startHourOnlyAppliesToTodayAfterFive() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let day = Day(iso: "2026-11-14")!
        let late = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 11, minute: 20))!
        let early = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 4, minute: 10))!

        #expect(PlannedBriefingLoader.startHour(planDay: day, today: day, now: late, calendar: calendar) == 12)
        #expect(PlannedBriefingLoader.startHour(planDay: day, today: day, now: early, calendar: calendar) == nil)
        #expect(PlannedBriefingLoader.startHour(planDay: Day(iso: "2026-11-15")!, today: day, now: late, calendar: calendar) == nil)
    }

    @Test func weatherRequestUsesRoundedCoordinateAndParsesDayHours() throws {
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
        #expect(hours == [HourlyWeather(hour: 5, temperature: 19.1, dewPoint: 15.4), HourlyWeather(hour: 11, temperature: 30.5, dewPoint: 16.0)])
    }

    @Test func plannedChatContextCarriesStepsPreviousRunsAndWeek() {
        let input = Self.input(Self.intervals)
        let briefing = PlannedBriefingBuilder.briefing(input)

        let context = PlannedChatContextBuilder.context(title: Self.intervals.title, dateText: "terça, 17 de novembro", input: input, briefing: briefing)

        #expect(context.copy.factsHeader == WorkoutChatConstants.plannedCopy.factsHeader)
        #expect(context.facts.hasPrefix("Intervalado ter 17/11, terça, 17 de novembro."))
        #expect(context.blockLines.count == briefing.phases.count)
        #expect(context.similarLines.first == "8 de nov.: 18,0 km, pace 4:38/km, FC média 162 bpm, ritmo caiu 9 s/km no fim")
        #expect(context.dayLine == "prontidão de hoje 74; semana com 31,0 km feitos de 51,0 km planejados, meta de 45 km; 4 dias desde o último treino forte; prova Meia em 45 dias.")
        #expect(context.suggestions == WorkoutChatConstants.suggestionsPlannedIntervals)
    }
}
