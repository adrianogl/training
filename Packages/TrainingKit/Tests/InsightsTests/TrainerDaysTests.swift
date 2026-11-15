import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerDaysTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let paces = TrainerPaces(easy: 297, long: 285, threshold: 250, vo2max: 230)
    private let openTarget = TrainerTarget(kind: .text, name: "Ficar mais forte", text: "ficar mais forte")

    private func structure(_ kinds: [TrainerDayKind]) -> [Int: TrainerDayKind] {
        Dictionary(uniqueKeysWithValues: kinds.enumerated().map { ($0.offset + 1, $0.element) })
    }

    private func preference(_ runs: Int, optional: Bool = false, off: Set<Int> = [7], long: Int = 6) -> TrainerDayPreference {
        TrainerDayPreference(runs: runs, optional: optional, offDays: off, longDay: long)
    }

    private func session(_ weekday: Int, _ group: TrainerStrengthGroup) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: group, legLoad: group == .lower ? .heavy : .light, name: "Força")
    }

    private func kinds(_ structure: [Int: TrainerDayKind]) -> [TrainerDayKind] {
        (1...7).map { structure[$0] ?? .off }
    }

    private func strongInARow(_ structure: [Int: TrainerDayKind]) -> Bool {
        let strong: Set<TrainerDayKind> = [.threshold, .vo2max, .long]
        return (1...7).contains { strong.contains(structure[$0] ?? .off) && strong.contains(structure[$0 % 7 + 1] ?? .off) }
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 14, pace: 297, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 12, pace: 250, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 3), km: 12, pace: 297, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: 20, pace: 285, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_500, 5_000: 1_180])
    }

    private func plan(_ structure: [Int: TrainerDayKind], target: TrainerTarget? = nil, peak: Double = 70_000) -> TrainerPlan {
        TrainerEngine.create(
            target: target ?? openTarget, structure: structure, strength: [], history: history, today: monday, now: now,
            startMeters: peak, peakMeters: peak
        )
    }

    @Test func standardPreferenceGivesTheDefaultStructure() {
        #expect(TrainerEngine.suggestedStructure(.standard) == TrainerEngine.defaultStructure)
        #expect(TrainerDayPreference(structure: TrainerEngine.defaultStructure) == .standard)
    }

    @Test func fiveRunsGetTwoQualityDaysWithAFreeDayBetween() {
        let result = TrainerEngine.suggestedStructure(preference(5))

        #expect(kinds(result) == [.easy, .threshold, .off, .vo2max, .easy, .long, .off])
        #expect(TrainerEngine.qualityPerWeek(result) == 2)
        #expect(!TrainerEngine.alternatesQuality(result))
    }

    @Test func fourRunsGetOneQualityThatAlternatesBetweenWeeks() {
        let result = TrainerEngine.suggestedStructure(preference(4))

        #expect(kinds(result) == [.off, .threshold, .off, .easy, .easy, .long, .off])
        #expect(TrainerEngine.alternatesQuality(result))
        #expect(TrainerEngine.weekStructure(result, index: 1)[2] == .threshold)
        #expect(TrainerEngine.weekStructure(result, index: 2)[2] == .vo2max)
        let created = plan(result, peak: 50_000)
        let tuesdays = created.workouts.filter { TrainerEngine.weekdayNumber($0.day) == 2 }.prefix(4).map(\.kind)
        #expect(tuesdays == [.threshold, .vo2max, .threshold, .vo2max])
    }

    @Test func threeRunsSpreadAcrossTheWeek() {
        let result = TrainerEngine.suggestedStructure(preference(3))

        #expect(kinds(result) == [.off, .threshold, .off, .easy, .off, .long, .off])
    }

    @Test func sixRunsWithOptionalPutTheOptionalOnTheEveOfTheLong() {
        let result = TrainerEngine.suggestedStructure(preference(6, optional: true))

        #expect(result[5] == .optionalEasy)
        #expect(kinds(result).filter { $0 == .off }.count == 1)
    }

    @Test func sevenRunsHaveNoOffDayAndWarn() {
        let result = TrainerEngine.suggestedStructure(preference(7, off: []))
        let warnings = TrainerEngine.dayWarnings(structure: result, strength: [], peakMeters: 70_000, paces: paces, target: openTarget)

        #expect(!kinds(result).contains(.off))
        #expect(TrainerEngine.qualityPerWeek(result) == 2)
        #expect(!strongInARow(result))
        #expect(warnings.map(\.text).first == "A semana não tem dia off: nenhum dia de descanso.")
        #expect(warnings.contains { $0.text.hasPrefix("Com 7 corridas e rodagens de pelo menos 40 min") })
    }

    @Test func offDaysNeverGetARun() {
        let result = TrainerEngine.suggestedStructure(preference(5, off: [1, 3]))

        #expect(kinds(result) == [.off, .threshold, .off, .vo2max, .easy, .long, .easy])
        #expect(!strongInARow(result))
    }

    @Test func offDaysWithoutRoomForTheRulesStillRespectTheOffDays() {
        let result = TrainerEngine.suggestedStructure(preference(5, off: [1, 4]))
        let warnings = TrainerEngine.dayWarnings(structure: result, strength: [], peakMeters: 60_000, paces: paces, target: openTarget)

        #expect(result[1] == .off && result[4] == .off)
        #expect(kinds(result).filter { $0 != .off }.count == 5)
        #expect(TrainerEngine.qualityPerWeek(result) == 2)
        #expect(!warnings.isEmpty)
    }

    @Test func tooManyOffDaysKeepOnlyTheDaysLeft() {
        let result = TrainerEngine.suggestedStructure(preference(6, off: [1, 3, 7]))

        #expect(result[1] == .off && result[3] == .off && result[7] == .off)
        #expect(kinds(result).filter { $0 != .off }.count == 4)
    }

    @Test func sundayLongMovesTheQualityDays() {
        let result = TrainerEngine.suggestedStructure(preference(6, optional: true, off: [1], long: 7))

        #expect(kinds(result) == [.off, .easy, .threshold, .easy, .vo2max, .optionalEasy, .long])
    }

    @Test func validatorFlagsQualityOnTheEveOfTheLong() {
        let edited = structure([.easy, .threshold, .easy, .easy, .vo2max, .long, .off])
        let warnings = TrainerEngine.dayWarnings(structure: edited, strength: [], peakMeters: 70_000, paces: paces, target: openTarget)

        #expect(warnings == [TrainerDayWarning(days: [5, 6], text: "VO2 na véspera do longão: o longão cai com as pernas cansadas.")])
    }

    @Test func validatorFlagsStrongDaysInARowAndAfterTheLong() {
        let edited = structure([.easy, .threshold, .vo2max, .easy, .easy, .long, .threshold])
        let texts = TrainerEngine.dayWarnings(structure: edited, strength: [], peakMeters: 50_000, paces: paces, target: openTarget)

        #expect(texts.contains(TrainerDayWarning(
            days: [2, 3], text: "Limiar e VO2 em dias seguidos: deixe um dia leve ou off entre os dois."
        )))
        #expect(texts.contains(TrainerDayWarning(
            days: [6, 7], text: "Limiar no dia seguinte ao longão: falta um dia leve ou off para recuperar."
        )))
        #expect(texts.contains { $0.days == [7, 1] } == false)
        #expect(texts.contains { $0.text.hasPrefix("A semana não tem dia off") })
    }

    @Test func validatorFlagsQualityAfterLegStrength() {
        let warnings = TrainerEngine.dayWarnings(
            structure: TrainerEngine.defaultStructure, strength: [session(3, .lower), session(1, .upper)], peakMeters: 70_000,
            paces: paces, target: openTarget
        )

        #expect(warnings == [TrainerDayWarning(days: [4], text: "VO2 no dia seguinte à força de pernas de quarta.", isSoft: true)])
    }

    @Test func validatorShowsThePossiblePeakWhenTheVolumeDoesNotFit() {
        let four = TrainerEngine.suggestedStructure(preference(4))
        let warnings = TrainerEngine.dayWarnings(structure: four, strength: [], peakMeters: 70_000, paces: paces, target: openTarget)

        #expect(TrainerEngine.possiblePeak(structure: four, peakMeters: 70_000, paces: paces, target: openTarget) == 61_000)
        #expect(warnings.map(\.text) == ["Com 4 corridas, o pico possível é 61 km, não 70 km. Com 5 corridas, os 70 km cabem."])
        #expect(TrainerEngine.dayWarnings(
            structure: TrainerEngine.defaultStructure, strength: [], peakMeters: 70_000, paces: paces, target: openTarget
        ).isEmpty)
    }

    @Test func limitsComeFromTimeAndRoundDown() {
        #expect(TrainerEngine.easyLimit(paces: paces) == 15_000)
        #expect(TrainerEngine.longLimit(weekMeters: 70_000, paces: paces) == 21_000)
        #expect(TrainerEngine.longLimit(weekMeters: 120_000, paces: paces) == 31_000)
        #expect(TrainerEngine.sizedLong(25_000, weekMeters: 70_000, paces: paces) == 21_000)
        #expect(TrainerEngine.sizedLong(14_000, weekMeters: 30_000, paces: paces) == 10_000)
        #expect(TrainerEngine.sizedLong(8_000, weekMeters: 20_000, paces: paces) == 8_000)
    }

    @Test func generatedDistancesAreWholeKilometersWithinTheLimits() {
        let created = plan(TrainerEngine.defaultStructure, peak: 70_000)
        let easyCap = TrainerEngine.easyLimit(paces: created.paces)

        for workout in created.workouts where [.easy, .optionalEasy, .long].contains(workout.kind) {
            #expect(workout.totalMeters.truncatingRemainder(dividingBy: 1_000) == 0)
        }
        for workout in created.workouts where workout.kind == .easy { #expect(workout.totalMeters <= easyCap) }
        for workout in created.workouts where workout.kind == .optionalEasy { #expect((9_000...10_000).contains(workout.totalMeters)) }
        for workout in created.workouts where workout.kind == .easy { #expect(workout.totalMeters >= 9_000) }
        for week in created.weeks {
            let longest = week.baseLongMeters.map { week.longMeters > $0 } ?? false
            let share = longest ? 0.35 : 0.30
            let limit = min(TrainerEngine.floorKilometers(week.targetMeters * share), TrainerEngine.floorKilometers(150 * 60 / created.paces.long * 1_000))
            #expect(week.longMeters <= max(limit, 10_000))
        }
        let first = created.weeks[0]
        #expect(abs(first.plannedMeters - first.targetMeters) <= 2_000)
    }

    @Test func volumeThatDoesNotFitIsCappedByTheLimits() {
        let four = TrainerEngine.suggestedStructure(preference(4))
        let created = plan(four, peak: 70_000)
        let week = created.workouts.prefix(7)
        let cap = TrainerEngine.easyLimit(paces: created.paces)

        #expect(week.filter { $0.kind == .easy }.allSatisfy { $0.totalMeters == cap })
        #expect(created.weeks[0].plannedMeters < created.weeks[0].targetMeters)
    }

    @Test func easyRunsLastAtLeastFortyMinutes() {
        #expect(TrainerEngine.easyMinimum(paces: paces) == 9_000)
        #expect(TrainerEngine.optionalLimit(paces: paces) == 10_000)
        #expect(TrainerEngine.easyMinimum(paces: TrainerPaces(easy: 300, long: 285, threshold: 250, vo2max: 230)) == 8_000)
    }

    @Test func weekTooSmallForFortyMinuteRunsWarns() {
        let six = TrainerEngine.suggestedStructure(.standard)
        let warnings = TrainerEngine.dayWarnings(structure: six, strength: [], peakMeters: 50_000, paces: paces, target: openTarget)

        #expect(warnings.contains { $0.text.hasPrefix("Com 6 corridas e rodagens de pelo menos 40 min") })
    }

    @Test func qualityStaysProportionalToALowVolume() {
        let four = TrainerEngine.suggestedStructure(preference(4))
        let meters = TrainerEngine.peakWeekMeters(structure: four, peakMeters: 19_000, paces: paces, target: openTarget)
        let quality = four.filter { [.threshold, .vo2max].contains($0.value) }.map { meters[$0.key] ?? 0 }
        let longDay = four.first { $0.value == .long }?.key ?? 0

        #expect(quality.allSatisfy { $0 <= 3_000 + 19_000 * 0.17 + 1_000 })
        #expect(meters.filter { $0.key != longDay }.values.allSatisfy { $0 <= meters[longDay] ?? 0 })
    }

    @Test func qualityCapKeepsTheHighVolumePattern() {
        let meters = TrainerEngine.peakWeekMeters(
            structure: TrainerEngine.defaultStructure, peakMeters: 70_000, paces: paces, target: openTarget
        )

        #expect((meters[2] ?? 0) >= 3_000 + 10_000)
        #expect((meters[4] ?? 0) >= 3_000 + 5_000)
    }

    @Test func cappedQualityKeepsAtLeastTwoRepeats() {
        let vo2 = TrainerEngine.cappedQuality(
            TrainerQualitySession(kind: .vo2max, method: .intervals, blocks: [TrainerQualityBlock(repeats: 5, meters: 1_000)], closing: true),
            weekMeters: 19_000
        )
        let tempo = TrainerEngine.cappedQuality(
            TrainerQualitySession(kind: .threshold, method: .tempo, blocks: [TrainerQualityBlock(repeats: 1, meters: 10_000)], closing: false),
            weekMeters: 19_000
        )

        #expect(vo2.blocks == [TrainerQualityBlock(repeats: 2, meters: 1_000)])
        #expect(tempo.blocks == [TrainerQualityBlock(repeats: 1, meters: 3_000)])
    }

    @Test func peakWeekPreviewGivesKilometersPerDay() {
        let meters = TrainerEngine.peakWeekMeters(
            structure: TrainerEngine.defaultStructure, peakMeters: 70_000, paces: paces, target: openTarget
        )

        #expect(meters[6] == 20_000)
        #expect(meters[7] == 0)
        #expect((9_000...10_000).contains(meters[5] ?? 0))
        #expect(meters.values.allSatisfy { $0.truncatingRemainder(dividingBy: 1_000) == 0 })
        #expect(abs(meters.values.reduce(0, +) - 70_000) <= 2_000)
    }

    @Test func qualityNeverFallsLessThanFourDaysBeforeTheRace() throws {
        let raceDay = monday.adding(days: 21)
        let target = TrainerTarget(kind: .race, name: "10 km", date: raceDay, distanceMeters: 10_000, goalSeconds: 2_400)
        let edited = structure([.easy, .threshold, .easy, .easy, .vo2max, .long, .off])
        let created = plan(edited, target: target, peak: 50_000)

        let friday = try #require(created.workouts.first { $0.day == raceDay.adding(days: -3) })
        #expect(friday.kind == .easy && friday.totalMeters == 5_000)
        let tuesday = try #require(created.workouts.first { $0.day == raceDay.adding(days: -6) })
        #expect(tuesday.kind == .threshold)
    }

    @Test func createKeepsThePreferenceAndOldPlansInferIt() throws {
        let chosen = preference(4)
        let created = TrainerEngine.create(
            target: openTarget, structure: TrainerEngine.suggestedStructure(chosen), strength: [], history: history,
            today: monday, now: now, dayPreference: chosen
        )
        #expect(created.dayPreference == chosen)
        let roundTrip = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(created))
        #expect(roundTrip.dayPreference == chosen)

        let old = plan(TrainerEngine.defaultStructure)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "dayPreference")
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.dayPreference == .standard)
        #expect(decoded.structure == TrainerEngine.defaultStructure)
    }

    @Test func partialPreferenceJsonFallsBackToTheStandard() throws {
        let decoded = try JSONDecoder().decode(TrainerDayPreference.self, from: Data(#"{"runs":4}"#.utf8))

        #expect(decoded == TrainerDayPreference(runs: 4, optional: true, offDays: [7], longDay: 6))
    }

    @Test func editingThePreferenceRebuildsFromTheNextWeek() throws {
        let created = plan(TrainerEngine.defaultStructure)
        let chosen = preference(5)
        let structure = TrainerEngine.suggestedStructure(chosen)
        let volumes = TrainerEngine.volumes(of: created, history: history, today: monday)
        let edit = TrainerEngine.makeEdit(
            for: created, target: created.target, startMeters: volumes.start, peakMeters: volumes.peak, structure: structure,
            strength: created.strength, longMode: created.longMode, paceOverrides: created.paceOverrides, history: history, today: monday,
            dayPreference: chosen
        )
        #expect(edit.dayPreference == chosen)
        #expect(edit.structure == structure)

        let edited = TrainerEngine.adjust(created, history: history, today: monday, now: now, trigger: .edited(edit))
        #expect(edited.dayPreference == chosen)
        #expect(edited.structure == structure)
        let wednesday = try #require(edited.workouts.first { $0.day == monday.adding(days: 9) })
        #expect(wednesday.kind == .off)
    }
}
