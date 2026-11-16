import Foundation
import GarminAPI
import Insights
import MFIT
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class StrengthModel {
    var sessions: [StrengthSession] = []
    var program: MFITProgram?
    var weekWorkouts: [StrengthWorkout] = []
    var weekDays: [StrengthDay] = []
    var warnings: [String] = []
    var isLoaded = false
    var hasMFIT = false

    @ObservationIgnored private var known: [Int64: MFITWorkout] = [:]
    @ObservationIgnored private let store: StrengthProgramStore
    @ObservationIgnored private let schedule: StrengthSchedule
    @ObservationIgnored private let today: () -> Day

    private typealias C = StrengthConstants

    init(store: StrengthProgramStore = StrengthProgramStore(), schedule: StrengthSchedule = StrengthSchedule(), today: @escaping () -> Day = { Day.today() }) {
        self.store = store
        self.schedule = schedule
        self.today = today
        apply(store.load())
    }

    var todayWorkout: StrengthWorkout? {
        weekWorkouts.first { $0.day == today().iso }
    }

    var weeklyCounts: [Int] {
        StrengthHistory.weeklyCounts(sessions.map(\.day), weeks: C.historyWeeks, today: today())
    }

    var averagePerWeek: Double {
        StrengthHistory.average(weeklyCounts.dropLast()) ?? 0
    }

    func workout(id: Int64) -> StrengthWorkout? {
        if let scheduled = weekWorkouts.first(where: { $0.id == id }) { return scheduled }
        return known[id].map { StrengthWorkout(id: $0.id, day: "", title: $0.title, blocks: $0.blocks) }
    }

    func session(id: Int64) -> StrengthSession? {
        sessions.first { $0.id == id }
    }

    func blocks(forSession id: Int64) -> [StrengthBlock] {
        session(id: id)?.workoutId.flatMap { known[$0]?.blocks } ?? []
    }

    func levels(for workout: StrengthWorkout) -> [MuscleGroup: Int] {
        Self.levels(workout.blocks, scale: .session)
    }

    func levels(forSession id: Int64) -> [MuscleGroup: Int] {
        Self.levels(blocks(forSession: id), scale: .session)
    }

    var weekLevels: [MuscleGroup: Int] {
        StrengthMuscles.sets(weekWorkouts.flatMap { Self.entries($0.blocks) }).mapValues { StrengthMuscles.level($0, scale: .week) }
    }

    var weekSetCount: Int {
        weekWorkouts.reduce(0) { $0 + $1.totalSets }
    }

    var volumeRows: [StrengthVolumeRow] {
        let start = today().weekStart.adding(days: -7 * (C.volumeWeeks - 1))
        let perWeek: [[MuscleGroup: Double]] = (0..<C.volumeWeeks).map { index in
            let first = start.adding(days: 7 * index)
            let last = first.adding(days: 6)
            let entries = sessions.filter { first <= $0.day && $0.day <= last }
                .flatMap { session in Self.entries(blocks(forSession: session.id)) }
            return StrengthMuscles.sets(entries)
        }
        return C.volumeGroups.map { group in StrengthVolumeRow(group: group, weekly: perWeek.map { $0[group] ?? 0 }) }
    }

    @discardableResult
    func load(container: ModelContainer, client: MFITClient?, plan: TrainerPlan?) async -> Bool {
        hasMFIT = client != nil
        var fetchedProgram = client == nil
        if let client {
            do {
                let fetched = try await client.currentProgram(today: today().iso)
                apply(fetched.map(store.update(with:)) ?? store.clearProgram())
                fetchedProgram = true
            } catch {
                fetchedProgram = false
            }
        } else {
            program = nil
        }
        let start = today().weekStart
        weekWorkouts = schedule.workouts(program, from: start, through: start.adding(days: 6))
        sessions = Self.sessions(records: Self.records(in: ModelContext(container)), known: Array(known.values))
        weekDays = Self.days(start: start, plan: plan, workouts: weekWorkouts)
        warnings = StrengthWeek.legWarnings(weekDays.map { day in
            let workout = weekWorkouts.first { $0.day == day.day.iso }
            let categories = workout?.blocks.flatMap { $0.exercises.map(\.category) } ?? []
            return StrengthWeekDay(day: day.day, run: day.runKind, legs: StrengthMuscles.isLegDay(categories))
        })
        isLoaded = true
        return fetchedProgram
    }

    private func apply(_ cache: StrengthProgramCache) {
        program = cache.program
        known = Dictionary(cache.known.map { ($0.id, $0) }) { first, _ in first }
    }

    private static func entries(_ blocks: [StrengthBlock]) -> [(category: String?, sets: Int)] {
        blocks.flatMap { block in block.exercises.map { (category: $0.category, sets: block.sets) } }
    }

    private static func levels(_ blocks: [StrengthBlock], scale: StrengthScale) -> [MuscleGroup: Int] {
        StrengthMuscles.sets(entries(blocks)).mapValues { StrengthMuscles.level($0, scale: scale) }
    }

    struct Record: Sendable {
        let id: Int64
        let day: Day
        let name: String
        let seconds: Double?
        let averageHR: Double?
        let maxHR: Double?
    }

    nonisolated static func records(in context: ModelContext) -> [Record] {
        let key = C.typeKey
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.typeKey == key }, sortBy: [SortDescriptor(\.start, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).compactMap { record in
            guard let day = record.localDay.flatMap(Day.init(iso:)) else { return nil }
            return Record(id: record.activityId, day: day, name: record.name, seconds: record.duration, averageHR: record.averageHR, maxHR: record.maxHR)
        }
    }

    static func sessions(records: [Record], known: [MFITWorkout]) -> [StrengthSession] {
        let completions = known.flatMap { workout in workout.completions.map { (workout: workout, completion: $0) } }
        var used: Set<String> = []
        var result: [StrengthSession] = records.map { record in
            let sameDay = completions.filter { $0.completion.day == record.day.iso }
            let byTitle: (MFITWorkout) -> Bool = { $0.title.caseInsensitiveCompare(StrengthText.shortTitle(record.name).trimmingCharacters(in: .whitespaces)) == .orderedSame }
            let match = sameDay.first { byTitle($0.workout) } ?? sameDay.first
            let workout = match?.workout ?? known.first(where: byTitle)
            if let match { used.insert(key(match.workout, match.completion)) }
            return StrengthSession(
                id: record.id,
                day: record.day,
                title: workout?.title ?? record.name,
                minutes: record.seconds.map { Int(($0 / C.secondsPerMinute).rounded()) } ?? match?.completion.minutes,
                averageHR: record.averageHR.map { Int($0.rounded()) },
                maxHR: record.maxHR.map { Int($0.rounded()) },
                workoutId: workout?.id,
                effort: match?.completion.effort
            )
        }
        for entry in completions where !used.contains(key(entry.workout, entry.completion)) {
            guard let day = Day(iso: entry.completion.day) else { continue }
            result.append(StrengthSession(
                id: -(entry.workout.id &* C.syntheticIdFactor &+ Int64(C.syntheticEpoch.days(until: day))),
                day: day,
                title: entry.workout.title,
                minutes: entry.completion.minutes,
                averageHR: nil,
                maxHR: nil,
                workoutId: entry.workout.id,
                effort: entry.completion.effort
            ))
        }
        return result.sorted { $0.day > $1.day }
    }

    private static func key(_ workout: MFITWorkout, _ completion: MFITCompletion) -> String {
        "\(workout.id)-\(completion.day)"
    }

    private static func days(start: Day, plan: TrainerPlan?, workouts: [StrengthWorkout]) -> [StrengthDay] {
        (0..<7).map { offset in
            let day = start.adding(days: offset)
            let run = plan?.workouts.first { $0.day == day && $0.kind != .off }
            return StrengthDay(
                day: day,
                run: run.map { StrengthText.runLabel($0.kind, meters: $0.totalMeters) },
                runKind: run?.kind,
                strength: workouts.first { $0.day == day.iso }.map { StrengthText.shortTitle($0.title) }
            )
        }
    }
}
