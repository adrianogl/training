import Foundation
import GarminAPI
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@Suite struct DayAdjustWatchTests {
    private let day = Day(iso: "2026-11-24")!

    private func workout() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .threshold, title: "Limiar 11 km", totalMeters: 11_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000, paceLow: 318, paceHigh: 332),
            TrainerStep(kind: .work, repeats: 4, meters: 2_000, restSeconds: 120, paceLow: 243, paceHigh: 249),
        ], paceLow: 243, paceHigh: 249, rationale: "")
    }

    private func entries(
        score: Int? = 80, temperature: Double? = 12, dewPoint: Double? = 5, hour: Int = 7, origin: DayAdjustOrigin = .usual, heavyLegs: Bool = false
    ) -> DayAdjustEntries {
        DayAdjustEntries(
            day: day, hour: hour, origin: origin, score: score, temperature: temperature, dewPoint: dewPoint, radiation: nil,
            hotSessions: 0, heavyLegs: heavyLegs, computedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func plan(offset: Double = 0) -> PlannedWorkout {
        PlannedWorkout(id: 77, day: day.iso, title: "Limiar 11 km", estimatedSeconds: nil, estimatedMeters: 11_000, steps: [
            PlannedStep(kind: .warmup, meters: 3_000, target: .pace(fastest: 318, slowest: 332)),
            PlannedStep(kind: .other, repeats: 4, children: [
                PlannedStep(kind: .active, meters: 2_000, target: .pace(fastest: 243 + offset, slowest: 249 + offset)),
                PlannedStep(kind: .rest, seconds: 120),
            ]),
        ])
    }

    @Test func storeKeepsOnlyTheEntriesOfTheDay() throws {
        let store = TrainerDayAdjustStore(defaults: try #require(UserDefaults(suiteName: "day-adjust-\(UUID())")))
        #expect(store.load(day: day) == nil)
        store.save(entries(score: 64))
        #expect(store.load(day: day) == entries(score: 64))
        #expect(store.load(day: day.adding(days: 1)) == nil)
        #expect(store.clear(day: day.adding(days: 1)) == false)
        #expect(store.clear(day: day))
        #expect(store.load(day: day) == nil)
    }

    @Test func candidateUsesTheClosestForecastHour() {
        let forecast = [
            HourlyWeather(hour: 6, temperature: 20, dewPoint: 15, radiation: 10),
            HourlyWeather(hour: 9, temperature: 27, dewPoint: 21, radiation: 400),
        ]
        let early = DayAdjustWatchRules.candidate(
            day: day, score: 70, forecast: forecast, hour: 7, origin: .usual, hotSessions: 2, heavyLegs: true, now: .now
        )
        #expect(early.temperature == 20 && early.dewPoint == 15 && early.radiation == 10)
        #expect(early.hour == 7 && early.origin == .usual && early.hotSessions == 2 && early.heavyLegs)
        let late = DayAdjustWatchRules.candidate(day: day, score: 70, forecast: forecast, hour: 9, origin: .now, hotSessions: 0, heavyLegs: false, now: .now)
        #expect(late.temperature == 27 && late.origin == .now)
        let none = DayAdjustWatchRules.candidate(day: day, score: 70, forecast: [], hour: 9, origin: .usual, hotSessions: 0, heavyLegs: false, now: .now)
        #expect(none.temperature == nil)
    }

    @Test func keepsTheOldEntriesBelowThreeSeconds() {
        let base = entries(score: 64)
        #expect(DayAdjustWatchRules.keeps(existing: base, candidate: entries(score: 61), workout: workout()))
        #expect(!DayAdjustWatchRules.keeps(existing: base, candidate: entries(score: 64, temperature: 28, dewPoint: 22), workout: workout()))
        #expect(!DayAdjustWatchRules.keeps(existing: base, candidate: entries(score: 55), workout: workout()))
        #expect(!DayAdjustWatchRules.keeps(existing: nil, candidate: base, workout: workout()))
        #expect(DayAdjustWatchRules.keeps(existing: entries(score: 80, origin: .now), candidate: entries(score: 55), workout: workout()))
    }

    @Test func todayRunGoesWithTheDayAdjust() throws {
        let plain = try #require(TrainerSendBuilder.runItem(workout()))
        let item = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(score: 64)))
        #expect(item.key == plain.key)
        #expect(item.signature != plain.signature)
        #expect(item.planSignature == plain.signature)
        #expect(item.dayAdjustSeconds == 3)
        #expect(item.dayAdjust == entries(score: 64))
        #expect(item.heatShare == 0)
        #expect(item.runSteps.last == .repeated(times: 4, steps: [.interval(meters: 2_000, fastest: 246, slowest: 252), .rest(seconds: 120)]))
        #expect(item.runSteps.first == plain.runSteps.first)
        let records = [plain.key: TrainerSentRecord(workoutId: 1, signature: plain.signature, day: day.iso, kind: .run)]
        #expect(TrainerSendBuilder.status(item, records: records) == .changed)
    }

    @Test func swapRestAndOtherDaysGoAsPlanned() throws {
        let plain = try #require(TrainerSendBuilder.runItem(workout()))
        let swap = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(score: 55, temperature: 31, dewPoint: 25, heavyLegs: true)))
        #expect(swap.signature == plain.signature)
        #expect(swap.dayAdjustSeconds == nil)
        #expect(swap.dayAdjust != nil)
        let rest = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(score: 40)))
        #expect(rest.signature == plain.signature)
        var tomorrow = entries(score: 64)
        tomorrow.day = day.adding(days: 1)
        let other = try #require(TrainerSendBuilder.runItem(workout(), entries: tomorrow))
        #expect(other == plain)
    }

    @Test func heatGoesIntoTheRecordShare() throws {
        let hot = entries(temperature: 28, dewPoint: 22)
        let item = try #require(TrainerSendBuilder.runItem(workout(), entries: hot))
        #expect((item.heatShare ?? 0) > 0)
        #expect(item.heatShare == TrainerDayAdjust.heatShare(hot))
    }

    @MainActor @Test func senderRecordsTheEntriesUsed() async throws {
        let store = TrainerSendStore(defaults: try #require(UserDefaults(suiteName: "sender-day-\(UUID())")))
        let item = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(temperature: 28, dewPoint: 22)))
        let result = await TrainerSender.send([item], stale: [], store: store, create: { _ in 42 }, remove: { _ in })
        #expect(result.sent == 1)
        let record = try #require(store.records()[item.key])
        #expect(record.dayAdjust == item.dayAdjust)
        #expect(record.heatShare == item.heatShare)
    }

    @Test func oldRecordsStillDecode() throws {
        let json = #"{"workoutId":5,"signature":"abc","day":"2026-11-20","kind":"run"}"#
        let record = try JSONDecoder().decode(TrainerSentRecord.self, from: Data(json.utf8))
        #expect(record.dayAdjust == nil && record.heatShare == nil)
        var updated = record
        updated.dayAdjust = entries()
        let decoded = try JSONDecoder().decode(TrainerSentRecord.self, from: JSONEncoder().encode(updated))
        #expect(decoded == updated)
    }

    @Test func watchEntriesComeFromTheRecordOrTheCurrentItem() throws {
        let item = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(score: 64)))
        let withEntries = TrainerSentRecord(workoutId: 77, signature: "x", day: day.iso, kind: .run, dayAdjust: entries(score: 61), heatShare: 0)
        #expect(DayAdjustWatchRules.entries(record: withEntries, item: item, planId: 77) == entries(score: 61))
        #expect(DayAdjustWatchRules.entries(record: withEntries, item: item, planId: 78) == nil)
        let current = TrainerSentRecord(workoutId: 77, signature: item.signature, day: day.iso, kind: .run)
        #expect(DayAdjustWatchRules.entries(record: current, item: item, planId: 77) == entries(score: 64))
        let stalePlan = TrainerSentRecord(workoutId: 77, signature: "antigo", day: day.iso, kind: .run)
        #expect(DayAdjustWatchRules.entries(record: stalePlan, item: item, planId: 77) == nil)
        #expect(DayAdjustWatchRules.entries(record: nil, item: item, planId: 77) == nil)
    }

    @Test func cardShowsWhatIsOnTheWatchWithTheOriginalPace() throws {
        let stored = entries(score: 64)
        let watch = DayAdjustWatch(entries: stored, workout: workout(), result: TrainerDayAdjust.adjust(workout(), entries: stored), sentAt: nil)
        let display = DayAdjustText.watchDisplay(watch, plan: plan(offset: 3))
        #expect(display.steps == plan(offset: 3).steps)
        #expect(display.original == plan().steps)
        #expect(display.notice?.title.contains("+3") == true)
        #expect(display.notice?.chips.isEmpty == false)

        let none = DayAdjustWatch(entries: entries(), workout: workout(), result: .none, sentAt: nil)
        let plain = DayAdjustText.watchDisplay(none, plan: plan())
        #expect(plain.notice == nil && plain.original == nil)
    }

    @Test func statusLineShowsSendTimeAndForecastHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let sent = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 6, minute: 5)))
        let watch = DayAdjustWatch(entries: entries(hour: 7), workout: workout(), result: .none, sentAt: sent)
        #expect(DayAdjustWatchRules.status(watch, calendar: calendar) == "No relógio desde 6h05 · clima das 7h")
        let unsent = DayAdjustWatch(entries: entries(hour: 7), workout: workout(), result: .none, sentAt: nil)
        #expect(DayAdjustWatchRules.status(unsent, calendar: calendar) == nil)
    }

    @Test func nowButtonOnlyWhenTheForecastNowChangesThreeSeconds() {
        let stored = entries(score: 64, temperature: 20, dewPoint: 10, hour: 7)
        let watch = DayAdjustWatch(entries: stored, workout: workout(), result: TrainerDayAdjust.adjust(workout(), entries: stored), sentAt: nil)
        #expect(DayAdjustWatchRules.showsNow(watch, now: entries(score: 64, temperature: 29, dewPoint: 23, hour: 10, origin: .now)))
        #expect(!DayAdjustWatchRules.showsNow(watch, now: entries(score: 64, temperature: 20, dewPoint: 10, hour: 8, origin: .now)))
        #expect(!DayAdjustWatchRules.showsNow(watch, now: entries(score: 64, temperature: 29, dewPoint: 23, hour: 7, origin: .now)))
    }

    @Test func retimedKeepsScoreLegsAndAdaptationAndMarksAsChosen() {
        var stored = entries(score: 64, temperature: 20, dewPoint: 10, hour: 7, heavyLegs: true)
        stored.hotSessions = 4
        let forecast = [HourlyWeather(hour: 18, temperature: 27, dewPoint: 20), HourlyWeather(hour: 20, temperature: 23, dewPoint: 18)]

        let moved = DayAdjustWatchRules.retimed(stored, forecast: forecast, hour: 20, now: Date(timeIntervalSince1970: 10))

        #expect(moved.hour == 20)
        #expect(moved.origin == .now)
        #expect(moved.temperature == 23)
        #expect(moved.score == 64)
        #expect(moved.heavyLegs)
        #expect(moved.hotSessions == 4)
    }

    @Test func laterOptionsPinTheWatchHourAndPickTheCoolest() {
        let stored = entries(score: 80, temperature: 24, dewPoint: 19, hour: 19)
        let watch = DayAdjustWatch(entries: stored, workout: workout(), result: TrainerDayAdjust.adjust(workout(), entries: stored), sentAt: nil)
        let temperatures: [Int: Double] = [11: 30, 13: 31, 14: 31, 15: 30, 16: 28, 17: 26, 18: 25, 19: 24, 20: 22, 21: 21, 22: 20]
        let forecast = temperatures.keys.sorted().map { HourlyWeather(hour: $0, temperature: temperatures[$0]!, dewPoint: 19) }

        let options = DayAdjustWatchRules.laterOptions(watch, forecast: forecast, currentHour: 12, now: .now)

        #expect(options.map(\.hour) == [19, 20, 21])
        #expect(options.allSatisfy { $0.entries.origin == .now })
        #expect(DayAdjustWatchRules.matchesWatch(options[0], watch: watch))
        #expect(!DayAdjustWatchRules.matchesWatch(options[2], watch: watch) || options[2].seconds == DayAdjustWatchRules.seconds(watch.result))
        #expect(options[0].seconds >= options[2].seconds)
    }

    @Test func laterOptionsSkipPastHoursAndLateNight() {
        let stored = entries(hour: 7)
        let watch = DayAdjustWatch(entries: stored, workout: workout(), result: .none, sentAt: nil)
        let forecast = (5...23).map { HourlyWeather(hour: $0, temperature: 26, dewPoint: 20) }

        let options = DayAdjustWatchRules.laterOptions(watch, forecast: forecast, currentHour: 20, now: .now)

        #expect(options.map(\.hour) == [21])
    }

    @Test func morningLineUsesTheStoredEntries() {
        let result = TrainerDayAdjust.adjust(workout(), entries: entries(score: 64))
        let line = DayAdjustText.trainerMorning(result, plan: plan())
        #expect(line?.contains("4:06–4:12") == true)
        #expect(DayAdjustText.trainerMorning(.none, plan: plan()) == nil)
    }

    @Test func dayViewAndWeekRowShowTheAdjustedPace() throws {
        guard case let .adjusted(change) = TrainerDayAdjust.adjust(workout(), entries: entries(score: 64)) else {
            Issue.record("esperava ajuste")
            return
        }
        #expect(TrainerText.dayAdjustLine(change) == "Ajuste do dia · +3 s/km · era \(TrainerText.paceRange(low: 243, high: 249) ?? "")")
        let line = TrainerText.dayLine(change.workout)
        #expect(line.detail.contains("4:06"))
        #expect(!TrainerText.dayLine(workout()).detail.contains("4:06"))
    }

    @Test func sendSheetCaptionOnlyWhenTheDayAdjustChangedIt() throws {
        let plain = try #require(TrainerSendBuilder.runItem(workout()))
        let item = try #require(TrainerSendBuilder.runItem(workout(), entries: entries(score: 64)))
        let planOnWatch = TrainerSentRecord(workoutId: 1, signature: plain.signature, day: day.iso, kind: .run)
        #expect(DayAdjustWatchRules.sendCaption(item, record: planOnWatch) == "Ajuste do dia: +3 s/km")
        let current = TrainerSentRecord(workoutId: 1, signature: item.signature, day: day.iso, kind: .run)
        #expect(DayAdjustWatchRules.sendCaption(item, record: current) == nil)
        let otherPlan = TrainerSentRecord(workoutId: 1, signature: "outro", day: day.iso, kind: .run)
        #expect(DayAdjustWatchRules.sendCaption(item, record: otherPlan) == nil)
        #expect(DayAdjustWatchRules.sendCaption(plain, record: planOnWatch) == nil)
    }

    private func at(_ seconds: Double, _ value: DayAdjustEntries) -> DayAdjustEntries {
        var copy = value
        copy.computedAt = Date(timeIntervalSince1970: seconds)
        return copy
    }

    @Test func twoDevicesWithDifferentLocalEntriesSendTheSameItem() throws {
        let sent = at(1_000, entries(score: 64, temperature: 22, dewPoint: 14, hour: 7))
        let sentItem = try #require(TrainerSendBuilder.runItem(workout(), entries: sent))
        let record = TrainerSentRecord(
            workoutId: 77, signature: sentItem.signature, day: day.iso, kind: .run, dayAdjust: sent, heatShare: sentItem.heatShare,
            title: sentItem.title
        )
        let records = [sentItem.key: record]
        let phone = TrainerDayAdjustStore(defaults: try #require(UserDefaults(suiteName: "phone-\(UUID())")))
        let pad = TrainerDayAdjustStore(defaults: try #require(UserDefaults(suiteName: "pad-\(UUID())")))
        phone.save(at(500, entries(score: 80, hour: 6)))
        pad.save(at(1_200, entries(score: 62, temperature: 22, dewPoint: 14, hour: 9)))
        for store in [phone, pad] {
            let effective = DayAdjustWatchRules.effective(local: store.load(day: day), record: record.dayAdjust, workout: workout())
            #expect(effective == sent)
            let item = try #require(TrainerSendBuilder.runItem(workout(), entries: effective))
            #expect(item.signature == record.signature)
            #expect(TrainerSendBuilder.status(item, records: records) == .current)
        }
    }

    @Test func newerLocalEntriesOnlyWinWhenTheyChangeTheWatch() {
        let sent = at(1_000, entries(score: 64, hour: 7))
        let close = at(2_000, entries(score: 61, hour: 9))
        let hotter = at(2_000, entries(score: 64, temperature: 29, dewPoint: 23, hour: 9))
        let tapped = at(2_000, entries(score: 64, hour: 9, origin: .now))
        #expect(DayAdjustWatchRules.effective(local: close, record: sent, workout: workout()) == sent)
        #expect(DayAdjustWatchRules.effective(local: hotter, record: sent, workout: workout()) == hotter)
        #expect(DayAdjustWatchRules.effective(local: tapped, record: sent, workout: workout()) == tapped)
        let sentNow = at(1_000, entries(score: 64, hour: 9, origin: .now))
        #expect(DayAdjustWatchRules.effective(local: hotter, record: sentNow, workout: workout()) == sentNow)
        #expect(DayAdjustWatchRules.effective(local: close, record: nil, workout: workout()) == close)
        var yesterday = sent
        yesterday.day = day.adding(days: -1)
        #expect(DayAdjustWatchRules.effective(local: close, record: yesterday, workout: workout()) == close)
    }

    @Test func remoteLedgerEntriesBecomeTheLocalEntries() throws {
        let defaults = try #require(UserDefaults(suiteName: "merge-\(UUID())"))
        let clock = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 9)))
        let today = Day.today(now: clock)
        var remoteEntries = at(clock.timeIntervalSince1970 - 60, entries(score: 64))
        remoteEntries.day = today
        let local = TrainerDayAdjustStore(defaults: defaults)
        var older = at(clock.timeIntervalSince1970 - 3_600, entries(score: 80))
        older.day = today
        local.save(older)
        let send = TrainerSendStore(defaults: defaults, now: { clock })
        let record = TrainerSentRecord(workoutId: 5, signature: "s", day: today.iso, kind: .run, dayAdjust: remoteEntries, heatShare: 0, title: "Limiar 11 km")
        let remote = TrainerSendLedger(entries: ["run|" + today.iso: TrainerSendLedgerEntry(record: record, updatedAt: clock)])
        send.merge(remote: remote)
        #expect(local.load(day: today) == remoteEntries)
    }

    @Test func includedHeatSurvivesTheLedgerLosingTheRecord() throws {
        let store = IncludedHeatStore(defaults: try #require(UserDefaults(suiteName: "heat-\(UUID())")))
        let record = TrainerSentRecord(workoutId: 5, signature: "s", day: day.iso, kind: .run, dayAdjust: entries(), heatShare: 0.03, title: "Limiar 11 km")
        store.absorb(["run|" + day.iso: record])
        store.absorb([:])
        #expect(store.all()[day] == IncludedHeat(share: 0.03, title: "Limiar 11 km"))
        var cooler = record
        cooler.heatShare = 0
        store.absorb(["run|" + day.iso: cooler])
        #expect(store.all()[day]?.share == 0)
        store.absorb(["strength|" + day.iso + "|a": record])
        #expect(store.all()[day]?.share == 0)
    }

    @Test func includedHeatOnlyGoesToTheRunOfTheSentWorkout() {
        let sentRun = WorkoutDetailFixtures.run(id: 1, meters: 11_000, workoutName: "Limiar 11 km")
        let heat = [WorkoutAnalysisContext.day(sentRun): IncludedHeat(share: 0.03, title: "Limiar 11 km")]
        let second = WorkoutDetailFixtures.run(id: 2, daysAgo: -0.01, meters: 5_000, workoutName: "Rodagem 5 km")
        let free = WorkoutDetailFixtures.run(id: 3, daysAgo: -0.02, meters: 5_000)
        let repeated = WorkoutDetailFixtures.run(id: 4, daysAgo: -0.03, meters: 11_000, workoutName: "Limiar 11 km")
        let otherDay = WorkoutDetailFixtures.run(id: 5, daysAgo: 1, meters: 11_000, workoutName: "Limiar 11 km")
        let map = DayAdjustWatchRules.includedHeatByActivity([second, free, repeated, sentRun, otherDay], heat: heat)
        #expect(map == [1: 0.03])
        #expect(DayAdjustWatchRules.includedHeatByActivity([second, free], heat: heat).isEmpty)
    }
}
