import Foundation
import GarminAPI
import Insights
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class StrengthModel {
    var sessions: [StrengthSession] = []
    var weekWorkouts: [StrengthWorkout] = []
    var sets: [Int64: [StrengthSet]] = [:]
    var weekDays: [StrengthDay] = []
    var warnings: [String] = []
    var isLoaded = false
    var hasGarminAccount = false

    @ObservationIgnored private let store: StrengthSetStore
    @ObservationIgnored private let today: () -> Day

    private typealias C = StrengthConstants

    init(store: StrengthSetStore = StrengthSetStore(), today: @escaping () -> Day = { Day.today() }) {
        self.store = store
        self.today = today
        self.sets = store.load()
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
        weekWorkouts.first { $0.id == id }
    }

    func session(id: Int64) -> StrengthSession? {
        sessions.first { $0.id == id }
    }

    func levels(for workout: StrengthWorkout) -> [MuscleGroup: Int] {
        let entries = workout.blocks.flatMap { block in block.exercises.map { (category: $0.category, sets: block.sets) } }
        return StrengthMuscles.sets(entries).mapValues { StrengthMuscles.level($0, scale: .session) }
    }

    func levels(forSession id: Int64) -> [MuscleGroup: Int] {
        let entries = (sets[id] ?? []).map { (category: $0.category, sets: 1) }
        return StrengthMuscles.sets(entries).mapValues { StrengthMuscles.level($0, scale: .session) }
    }

    var weekLevels: [MuscleGroup: Int] {
        weekSets.mapValues { StrengthMuscles.level($0, scale: .week) }
    }

    var weekSetCount: Int {
        weekWorkouts.reduce(0) { $0 + $1.totalSets }
    }

    private var weekSets: [MuscleGroup: Double] {
        let entries = weekWorkouts.flatMap { workout in
            workout.blocks.flatMap { block in block.exercises.map { (category: $0.category, sets: block.sets) } }
        }
        return StrengthMuscles.sets(entries)
    }

    var volumeRows: [StrengthVolumeRow] {
        let start = today().weekStart.adding(days: -7 * (C.volumeWeeks - 1))
        let perWeek: [[MuscleGroup: Double]] = (0..<C.volumeWeeks).map { index in
            let first = start.adding(days: 7 * index)
            let last = first.adding(days: 6)
            let entries = sessions.filter { first <= $0.day && $0.day <= last }
                .flatMap { session in (sets[session.id] ?? []).map { (category: $0.category, sets: 1) } }
            return StrengthMuscles.sets(entries)
        }
        return C.volumeGroups.map { group in StrengthVolumeRow(group: group, weekly: perWeek.map { $0[group] ?? 0 }) }
    }

    func results(for session: StrengthSession) -> [StrengthExerciseResult] {
        let done = sets[session.id] ?? []
        guard let planned = plannedWorkout(for: session) else {
            let grouped = Dictionary(grouping: done) { $0.exerciseKey ?? $0.category ?? "" }
            return grouped.keys.sorted().map { key in
                let list = grouped[key] ?? []
                return StrengthExerciseResult(name: StrengthWorkouts.displayName(key), planned: list.count, done: list.count, reps: list.map(\.reps))
            }
        }
        return planned.blocks.flatMap { block in
            block.exercises.map { exercise in
                let category = exercise.category
                let matching = done.filter { $0.category == category && ($0.exerciseKey == nil || exercise.exerciseKey == nil || $0.exerciseKey == exercise.exerciseKey) }
                return StrengthExerciseResult(name: exercise.name, planned: block.sets, done: min(matching.count, block.sets), reps: matching.prefix(block.sets).map(\.reps))
            }
        }
    }

    @ObservationIgnored private var templates: [String: StrengthWorkout] = [:]

    private func plannedWorkout(for session: StrengthSession) -> StrengthWorkout? {
        weekWorkouts.first { $0.title == session.title } ?? templates[session.title]
    }

    func load(container: ModelContainer, client: GarminAccountClient?, plan: TrainerPlan?) async {
        sessions = Self.sessions(in: ModelContext(container))
        hasGarminAccount = client != nil
        let start = today().weekStart
        if let client {
            if let workouts = try? await StrengthWorkouts.fetch(client: client, from: start, through: start.adding(days: 6)) {
                weekWorkouts = workouts
                for workout in workouts { templates[workout.title] = workout }
            }
        }
        weekDays = Self.days(start: start, plan: plan, workouts: weekWorkouts)
        warnings = StrengthWeek.legWarnings(weekDays.map { day in
            let workout = weekWorkouts.first { $0.day == day.day.iso }
            let categories = workout?.blocks.flatMap { $0.exercises.map(\.category) } ?? []
            return StrengthWeekDay(day: day.day, run: day.runKind, legs: StrengthMuscles.isLegDay(categories))
        })
        isLoaded = true
        if let client { await backfillSets(client: client) }
    }

    private func backfillSets(client: GarminAccountClient) async {
        let since = today().adding(days: -7 * C.setsBackfillWeeks)
        let missing = sessions.filter { $0.day >= since && sets[$0.id] == nil }.prefix(C.maxBackfillPerLoad)
        guard !missing.isEmpty else { return }
        for session in missing {
            guard let fetched = try? await ExerciseSets.fetch(client: client, activityId: session.id) else { continue }
            sets[session.id] = fetched
        }
        store.save(sets)
    }

    nonisolated private static func sessions(in context: ModelContext) -> [StrengthSession] {
        let key = StrengthConstants.typeKey
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.typeKey == key }, sortBy: [SortDescriptor(\.start, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).compactMap { record in
            guard let day = record.localDay.flatMap(Day.init(iso:)) else { return nil }
            return StrengthSession(
                id: record.activityId,
                day: day,
                title: record.name,
                minutes: record.duration.map { Int(($0 / StrengthConstants.secondsPerMinute).rounded()) },
                averageHR: record.averageHR.map { Int($0.rounded()) },
                maxHR: record.maxHR.map { Int($0.rounded()) }
            )
        }
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
