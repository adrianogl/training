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
    var loadSeries: [StrengthLoadSeries] = []
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

    var weekTitles: [Day: String] {
        Dictionary(weekWorkouts.compactMap { workout in Day(iso: workout.day).map { ($0, workout.title) } }) { first, _ in first }
    }

    func legDay(before day: Day, planned: StrengthPlannedLegs? = nil) -> StrengthLegDay? {
        Self.legDay(sessions: sessions, known: known, planned: planned, before: day)
    }

    nonisolated static func legDay(
        in context: ModelContext, store: StrengthProgramStore = StrengthProgramStore(), planned: StrengthPlannedLegs? = nil, before day: Day
    ) -> StrengthLegDay? {
        let known = store.load().known
        let sessions = Self.sessions(records: records(in: context), known: known)
        return legDay(sessions: sessions, known: Dictionary(known.map { ($0.id, $0) }) { first, _ in first }, planned: planned, before: day)
    }

    nonisolated static func legDay(
        sessions: [StrengthSession], known: [Int64: MFITWorkout], planned: StrengthPlannedLegs? = nil, before day: Day
    ) -> StrengthLegDay? {
        let yesterday = day.adding(days: -1)
        let done = sessions.filter { $0.day == yesterday }
        for session in done {
            let entries = Self.entries(session.workoutId.flatMap { known[$0]?.blocks } ?? [])
            guard StrengthMuscles.isLegDay(entries) else { continue }
            return StrengthLegDay(title: StrengthText.shortTitle(session.title), sets: entries.reduce(0) { $0 + $1.sets }, legSets: StrengthMuscles.legSets(entries))
        }
        guard let planned, let session = done.first(where: { $0.workoutId.flatMap { known[$0] } == nil }) else { return nil }
        return StrengthLegDay(title: StrengthText.shortTitle(session.title), sets: planned.sets, legSets: planned.legSets)
    }

    func weekSummary(start: Day) -> WeeklyStrengthSummary? {
        let end = start.adding(days: 6)
        let planned = schedule.workouts(program, from: start, through: end)
        let done = sessions.filter { start <= $0.day && $0.day <= end }
        guard !planned.isEmpty || !done.isEmpty else { return nil }
        let doneBlocks = done.map { blocks(forSession: $0.id) }
        let totals = StrengthMuscles.sets(doneBlocks.flatMap { Self.entries($0) })
        let groups = totals.filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(C.reportGroupsLimit)
            .map { StrengthGroupTotal(group: $0.key, sets: $0.value, level: StrengthMuscles.level($0.value, scale: .week)) }
        let records = loadSeries.compactMap { series -> WeeklyStrengthRecord? in
            guard let index = series.points.lastIndex(where: { start <= $0.day && $0.day <= end }), index > 0 else { return nil }
            let earlier = series.points[..<index].map(\.top).max() ?? 0
            let point = series.points[index]
            return point.top > earlier ? WeeklyStrengthRecord(name: series.name, top: point.top, gain: point.top - earlier) : nil
        }
        let doneDays = Set(done.map(\.day.iso))
        let missed = planned.filter { $0.day < today().iso && !doneDays.contains($0.day) }.compactMap { workout in
            Day(iso: workout.day).map { StrengthText.missedLabel(workout.title, day: $0) }
        }
        let titles = Dictionary(planned.compactMap { workout in Day(iso: workout.day).map { ($0, workout.title) } }) { first, _ in first }
        return WeeklyStrengthSummary(
            done: done.count,
            planned: planned.count,
            sets: doneBlocks.reduce(0) { $0 + $1.reduce(0) { $0 + $1.sets * $1.exercises.count } },
            groups: Array(groups),
            records: records,
            missed: missed,
            titles: titles
        )
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

    var weekGroupTotals: [StrengthGroupTotal] {
        let sets = StrengthMuscles.sets(weekWorkouts.flatMap { Self.entries($0.blocks) })
        return sets.filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(C.groupTotalsLimit)
            .map { StrengthGroupTotal(group: $0.key, sets: $0.value, level: StrengthMuscles.level($0.value, scale: .week)) }
    }

    var volumeWeekStarts: [Day] {
        let start = today().weekStart.adding(days: -7 * (C.volumeWeeks - 1))
        return (0..<C.volumeWeeks).map { start.adding(days: 7 * $0) }
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
    func load(container: ModelContainer, client: MFITClient?, plan: TrainerPlan?, garmin: GarminAccountClient? = nil) async -> Bool {
        hasMFIT = client != nil
        let records = Self.records(in: ModelContext(container))
        sessions = Self.sessions(records: records, known: Array(known.values))
        var fetchedProgram = client == nil
        if let client {
            do {
                let fetched = try await client.currentProgram(today: today().iso)
                apply(fetched.map(store.update(with:)) ?? store.clearProgram())
                if let ids = fetched?.workouts.map(\.id), let records = try? await client.loadRecords(workoutIds: ids) {
                    apply(store.updateLoads(records, fetched: Set(ids)))
                }
                fetchedProgram = true
            } catch {
                fetchedProgram = false
            }
        } else {
            program = nil
        }
        let start = today().weekStart
        weekWorkouts = schedule.workouts(program, from: start, through: start.adding(days: 6))
        sessions = Self.sessions(records: records, known: Array(known.values))
        weekDays = Self.days(start: start, plan: plan, workouts: weekWorkouts)
        warnings = StrengthWeek.legWarnings(weekDays.map { day in
            let workout = weekWorkouts.first { $0.day == day.day.iso }
            return StrengthWeekDay(day: day.day, run: day.runKind, legs: StrengthMuscles.isLegDay(Self.entries(workout?.blocks ?? [])))
        })
        isLoaded = true
        if let garmin { await importWatchLoads(garmin) }
        await StrengthRecordNotifier.notify(loadSeries, today: today())
        return fetchedProgram
    }

    private func importWatchLoads(_ garmin: GarminAccountClient) async {
        let processed = Set(store.load().watchProcessed)
        let since = today().adding(days: -7 * C.watchLoadsWeeks)
        let pending = sessions.filter { $0.id > 0 && $0.workoutId != nil && $0.day >= since && !processed.contains($0.id) }.prefix(C.watchLoadsPerLoad)
        for session in pending {
            guard let workoutId = session.workoutId, let workout = known[workoutId],
                  let sets = try? await ExerciseSets.fetch(client: garmin, activityId: session.id) else { continue }
            let records = StrengthWatchLoads.records(sets: sets, blocks: workout.blocks, workoutId: workoutId, day: session.day.iso)
            apply(store.addWatchLoads(records, activity: session.id))
        }
    }

    private func apply(_ cache: StrengthProgramCache) {
        program = cache.program
        known = Dictionary(cache.known.map { ($0.id, $0) }) { first, _ in first }
        loadSeries = Self.loadSeries(cache.loads, known: cache.known, current: cache.program?.workouts ?? [])
    }

    func loadSeries(key: String) -> StrengthLoadSeries? {
        loadSeries.first { $0.key == key }
    }

    static func loadSeries(_ records: [MFITLoadRecord], known: [MFITWorkout], current: [MFITWorkout]) -> [StrengthLoadSeries] {
        let titles = Dictionary(known.map { ($0.id, $0.title) }) { first, _ in first }
        return Dictionary(grouping: records, by: \.key).compactMap { key, list -> StrengthLoadSeries? in
            let byDay = Dictionary(grouping: list, by: \.day)
            let points = byDay.keys.sorted().compactMap { iso -> StrengthLoadPoint? in
                guard let day = Day(iso: iso), let entries = byDay[iso], let best = entries.max(by: { $0.top < $1.top }) else { return nil }
                return StrengthLoadPoint(day: day, top: best.top, loads: best.loads, workout: titles[best.workoutId] ?? "", fromWatch: best.fromWatch == true)
            }
            guard let latest = list.max(by: { $0.day < $1.day }), !points.isEmpty else { return nil }
            var workouts: [String] = []
            let appearsIn = current.sorted { $0.order < $1.order }.filter { workout in
                workout.blocks.contains { block in block.exercises.contains { MFITParser.exerciseKey($0.name) == key } }
            }.map(\.title)
            for title in appearsIn + list.compactMap({ titles[$0.workoutId] }) where !title.isEmpty && !workouts.contains(title) {
                workouts.append(title)
            }
            return StrengthLoadSeries(key: key, name: StrengthText.exerciseName(latest.exercise), workouts: workouts, points: points)
        }
        .sorted { ($0.points.last?.day ?? .today(), $1.name) > ($1.points.last?.day ?? .today(), $0.name) }
    }

    nonisolated private static func entries(_ blocks: [StrengthBlock]) -> [(category: String?, sets: Int)] {
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

    nonisolated static func sessions(records: [Record], known: [MFITWorkout]) -> [StrengthSession] {
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

    nonisolated private static func key(_ workout: MFITWorkout, _ completion: MFITCompletion) -> String {
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
