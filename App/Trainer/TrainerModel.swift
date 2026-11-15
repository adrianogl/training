import Foundation
import GarminAPI
import Insights
import Metrics
import Observation
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class TrainerModel {
    private(set) var plan: TrainerPlan?
    private(set) var history = TrainerHistory(runs: [])
    private(set) var seenVersion: Int
    private(set) var isLoaded = false
    private(set) var isWorking = false
    private(set) var saveFailed = false
    private(set) var externalWorkouts: [TrainerExternalWorkout] = []
    private(set) var keptReadinessDay: String?

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let store: TrainerStore
    @ObservationIgnored private let today: @Sendable () -> Day
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var autoTask: Task<Void, Never>?
    @ObservationIgnored private var loadedStamp: Date?
    @ObservationIgnored var onChange: @MainActor () -> Void = {}

    init(
        container: ModelContainer, store: TrainerStore = TrainerStore(), today: @escaping @Sendable () -> Day = { Day.today() },
        defaults: UserDefaults = .standard
    ) {
        self.container = container
        self.store = store
        self.today = today
        self.defaults = defaults
        self.keptReadinessDay = defaults.string(forKey: TrainerConstants.readinessKeptDefaultsKey)
        self.seenVersion = store.seenVersion
        self.plan = store.load()
        self.loadedStamp = store.updatedAt()
    }

    var currentDay: Day { today() }

    var latestVersion: TrainerVersion? { plan?.versions.last }

    var hasUnseenVersion: Bool {
        guard let number = latestVersion?.number else { return false }
        return number > 1 && number > seenVersion
    }

    var changedDays: Set<Day> {
        Set((latestVersion?.changes ?? []).filter { $0.kind != .unchanged }.compactMap(\.day))
    }

    var changedWeeks: Set<Int> {
        Set((latestVersion?.changes ?? []).filter { $0.kind != .unchanged }.compactMap(\.weekIndex))
    }

    var weekGroups: [TrainerWeekGroup] {
        guard let plan else { return [] }
        let now = currentDay
        let grouped = Dictionary(grouping: plan.workouts.sorted { $0.day < $1.day }) { $0.day.weekStart }
        return grouped.keys.sorted().map { start in
            let week = plan.weeks.first { $0.start == start }
            return TrainerWeekGroup(
                start: start,
                title: TrainerText.weekTitle(index: week?.index, start: start),
                caption: TrainerText.weekCaption(plannedMeters: week?.plannedMeters),
                rows: (grouped[start] ?? []).map(row),
                isCurrent: start == now.weekStart,
                isPast: start < now.weekStart
            )
        }
    }

    var scoreboards: [TrainerScoreboard] {
        guard let plan else { return [] }
        return TrainerEngine.scoreboards(plan: plan, history: history, today: currentDay)
    }

    var compareWeeks: [TrainerComparisonWeek] {
        guard let plan else { return [] }
        let now = currentDay
        let first = now.weekStart.adding(days: -TrainerConstants.weekdayCount)
        return (0...TrainerConstants.externalWeeksAhead)
            .map { first.adding(days: $0 * TrainerConstants.weekdayCount) }
            .filter { start in externalWorkouts.contains { $0.day.weekStart == start } }
            .map { TrainerEngine.compare(plan: plan, external: externalWorkouts, history: history, week: $0, today: now) }
    }

    func loadExternal(client: GarminAccountClient?) async {
        guard let client else {
            externalWorkouts = []
            return
        }
        let first = currentDay.weekStart.adding(days: -TrainerConstants.weekdayCount)
        let last = first.adding(days: (TrainerConstants.externalWeeksAhead + 1) * TrainerConstants.weekdayCount - 1)
        guard let workouts = try? await PlannedWorkouts.fetch(client: client, from: first, through: last), !Task.isCancelled else { return }
        externalWorkouts = workouts.compactMap(TrainerExternalMapper.convert)
    }

    static func lowestFactor(_ breakdown: ReadinessBreakdown?) -> TrainerReadinessFactor? {
        let scored = (breakdown?.factors ?? []).compactMap { factor in factor.todayScore.map { (factor.component, $0) } }
        guard let lowest = scored.min(by: { $0.1 < $1.1 }) else { return nil }
        return TrainerReadinessFactor(name: TrainerConstants.readinessFactorNames[lowest.0] ?? "", value: Int(lowest.1.rounded()))
    }

    func readinessSuggestion(score: Int?, factor: TrainerReadinessFactor?) -> TrainerReadinessSuggestion? {
        guard let plan, let score, keptReadinessDay != currentDay.iso else { return nil }
        var seen = history
        seen.readiness[currentDay] = score
        return TrainerEngine.readinessSuggestion(plan: plan, history: seen, today: currentDay, factor: factor)
    }

    func keepReadiness(_ suggestion: TrainerReadinessSuggestion) {
        defaults.set(suggestion.day.iso, forKey: TrainerConstants.readinessKeptDefaultsKey)
        keptReadinessDay = suggestion.day.iso
    }

    func acceptReadiness(_ suggestion: TrainerReadinessSuggestion) async {
        guard let current = plan else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        let trigger = TrainerTrigger.readiness(day: suggestion.day, score: suggestion.score)
        persist(TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: trigger))
        markSeen()
    }

    var weekCells: [TrainerWeekCell] {
        guard let plan else { return [] }
        let now = currentDay
        var cells = plan.weeks.map { week in
            TrainerWeekCell(
                id: week.index,
                title: "S\(week.index) · \(week.start.day)/\(week.start.month)",
                kilometers: "\(TrainerText.kilometersNumber(week.plannedMeters)) km",
                detail: plan.lightWeeks.contains(week.start)
                    ? TrainerText.lightCell
                    : week.isRecovery
                    ? "\(TrainerText.recoveryWeek) \(TrainerText.kilometersNumber(week.longMeters))"
                    : "\(TrainerText.longRun) \(TrainerText.kilometersNumber(week.longMeters))",
                phase: week.phase,
                isCurrent: week.start <= now && now < week.start.adding(days: TrainerConstants.weekdayCount),
                isPast: week.start.adding(days: TrainerConstants.weekdayCount) <= now,
                isChanged: changedWeeks.contains(week.index),
                isRace: false,
                start: week.start,
                isLight: plan.lightWeeks.contains(week.start)
            )
        }
        if plan.target.kind == .race, let date = plan.target.date {
            cells.append(TrainerWeekCell(
                id: Int.max,
                title: "\(date.day)/\(date.month)",
                kilometers: TrainerText.kilometersNumber(plan.target.distanceMeters ?? 0),
                detail: TrainerText.raceCell,
                phase: nil,
                isCurrent: false,
                isPast: false,
                isChanged: false,
                isRace: true
            ))
        }
        return cells
    }

    var weeksToTarget: Int? {
        guard let date = plan?.target.date else { return nil }
        let days = currentDay.days(until: date)
        return days > 0 ? (days + TrainerConstants.weekdayCount - 1) / TrainerConstants.weekdayCount : nil
    }

    var currentWeekIndex: Int? {
        let now = currentDay
        return plan?.weeks.first { $0.start <= now && now < $0.start.adding(days: TrainerConstants.weekdayCount) }?.index
    }

    func row(for iso: String) -> TrainerDayRow? {
        plan?.workouts.first { $0.id == iso }.map(row)
    }

    func weekIndex(of day: Day) -> Int? {
        plan?.weeks.first { $0.start == day.weekStart }?.index
    }

    func raceOptions() -> [TrainerRaceOption] {
        let now = currentDay
        let races = (try? container.mainContext.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        return races.compactMap { race in
            guard let day = Day(iso: race.day), day >= now else { return nil }
            return TrainerRaceOption(id: race.id, name: race.name, day: day, distance: race.distance, goalSeconds: race.goalSeconds)
        }
        .sorted { $0.day < $1.day }
    }

    func previewStrength() -> [TrainerStrengthSession] {
        TrainerEngine.detectStrength(history: history, today: currentDay)
    }

    func strengthRows() -> [TrainerStrengthRow] {
        guard let plan else { return [] }
        let now = currentDay
        let since = now.adding(days: -TrainerConstants.strengthWeeks * TrainerConstants.weekdayCount)
        return plan.strength.sorted { $0.weekday < $1.weekday }.map { session in
            let seconds = history.strength
                .filter { $0.day > since && $0.day <= now && $0.day.weekStart.days(until: $0.day) + 1 == session.weekday }
                .map(\.seconds)
            let minutes = seconds.isEmpty ? nil : Int((seconds.reduce(0, +) / Double(seconds.count) / 60).rounded())
            let done = TrainerEngine.strengthWeeksDone(session, history: history, today: now)
            return TrainerStrengthRow(session: session, caption: TrainerText.strengthCaption(done: done, minutes: minutes))
        }
    }

    func saveStrength(_ sessions: [TrainerStrengthSession]) async {
        guard var current = plan else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        current.strength = sessions
        let adjusted = TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .strengthChanged)
        persist(adjusted)
        store.markStrengthMigrated()
        markSeen()
    }

    func previewWeeklyMeters() -> Double {
        TrainerEngine.averageWeeklyMeters(history: history, today: currentDay)
    }

    func previewPeakMeters(start: Double) -> Double {
        TrainerEngine.defaultPeak(from: start)
    }

    func previewWeeksToPeak(start: Double, peak: Double) -> Int {
        TrainerEngine.weeksToPeak(startMeters: start, peakMeters: peak)
    }

    func previewPaces() -> TrainerPaces {
        TrainerEngine.paces(history: history, today: currentDay)
    }

    func reloadFromStore() {
        let stamp = store.updatedAt()
        guard stamp != loadedStamp else { return }
        loadedStamp = stamp
        plan = store.load()
        seenVersion = store.seenVersion
    }

    func load() async {
        plan = store.load()
        loadedStamp = store.updatedAt()
        history = await loadHistory()
        isLoaded = true
        migrateStrength()
        applyPending()
    }

    func scheduleAutoAdjust() {
        autoTask?.cancel()
        autoTask = Task { [weak self] in
            guard let self else { return }
            self.reloadFromStore()
            guard self.plan != nil else { return }
            self.history = await self.loadHistory()
            guard !Task.isCancelled else { return }
            self.reloadFromStore()
            self.applyPending()
        }
    }

    func isLightWeek(_ start: Day) -> Bool { plan?.lightWeeks.contains(start) == true }

    func toggleLightWeek(_ start: Day) async {
        guard let plan else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        persist(TrainerEngine.adjust(plan, history: history, today: currentDay, now: .now, trigger: .lightWeek(start)))
        markSeen()
    }

    var longSuggestion: TrainerLongSuggestion? {
        TrainerEngine.longModeSuggestion(history: history, plan: plan, today: currentDay)
    }

    func setLongMode(_ mode: TrainerLongMode) async {
        guard let current = plan, current.longMode != mode else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        persist(TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .longModeChanged))
        markSeen()
    }

    func forecast(for day: Day) async -> [HourlyWeather] {
        guard day >= currentDay, currentDay.days(until: day) <= PlannedExtrasConstants.forecastDaysAhead,
              let coordinate = PlannedWeather.lastRunStart(context: container.mainContext) else { return [] }
        return await PlannedWeather.forecast(day: day, coordinate: coordinate)
    }

    func previewLightWeekStarts() -> [Day] {
        let first = currentDay.weekStart
        return (0..<TrainerConstants.lightWeekChoices).map { first.adding(days: $0 * TrainerConstants.weekdayCount) }
    }

    func createPlan(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession], startMeters: Double?,
        peakMeters: Double?, lightWeeks: [Day] = [], longMode: TrainerLongMode = .continuous
    ) async {
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        let created = TrainerEngine.create(
            target: target, structure: structure, strength: strength, history: history, today: currentDay, now: .now,
            startMeters: startMeters, peakMeters: peakMeters, lightWeeks: lightWeeks, longMode: longMode
        )
        persist(created)
        store.markStrengthMigrated()
        markSeen()
    }

    @discardableResult
    func request(_ request: TrainerRequest) async -> TrainerVersion? {
        guard let plan else { return nil }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        let adjusted = TrainerEngine.adjust(plan, history: history, today: currentDay, now: .now, trigger: .request(request))
        persist(adjusted)
        markSeen()
        return adjusted.versions.last
    }

    func editVolumes() -> (start: Int, peak: Int)? {
        guard let plan else { return nil }
        let volumes = TrainerEngine.volumes(of: plan, history: history, today: currentDay)
        return (
            Int((volumes.start / TrainerConstants.metersPerKilometer).rounded()),
            Int((volumes.peak / TrainerConstants.metersPerKilometer).rounded())
        )
    }

    func makeEdit(
        target: TrainerTarget, startMeters: Double, peakMeters: Double, structure: [Int: TrainerDayKind], longMode: TrainerLongMode,
        paceOverrides: [TrainerPaceKind: Double]
    ) -> TrainerEdit? {
        guard let plan else { return nil }
        return TrainerEngine.makeEdit(
            for: plan, target: target, startMeters: startMeters, peakMeters: peakMeters, structure: structure, strength: plan.strength,
            longMode: longMode, paceOverrides: paceOverrides, history: history, today: currentDay
        )
    }

    func previewEdit(_ edit: TrainerEdit) -> [TrainerChange] {
        guard let plan else { return [] }
        return TrainerEngine.previewEdit(plan, edit: edit, history: history, today: currentDay, now: .now)
    }

    func saveEdit(_ edit: TrainerEdit) async {
        guard let current = plan else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        persist(TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .edited(edit)))
        markSeen()
    }

    func canEdit(_ row: TrainerDayRow) -> Bool {
        (row.status == .planned || row.status == .today) && row.workout.day >= currentDay && TrainerEngine.isEditable(row.workout)
    }

    func swapCandidates(for day: Day) -> [Day] {
        guard let plan else { return [] }
        let now = currentDay
        return plan.workouts
            .filter { $0.day.weekStart == day.weekStart && $0.day != day && $0.day >= now && $0.kind != .race }
            .filter { workout in !history.runs.contains { $0.day == workout.day } }
            .map(\.day)
            .sorted()
    }

    func saveWorkoutEdit(day: Day, edited: TrainerWorkout?, swapWith other: Day?) {
        guard var current = plan else { return }
        if let edited { current = TrainerEngine.editWorkout(current, edited, now: .now) }
        if let other { current = TrainerEngine.swapWorkouts(current, day, other, now: .now) }
        guard current != plan else { return }
        persist(current)
        markSeen()
    }

    func revertWorkout(_ day: Day) async {
        guard let current = plan else { return }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        persist(TrainerEngine.revertWorkout(current, day: day, history: history, today: currentDay, now: .now))
        markSeen()
    }

    func deletePlan() {
        do {
            try store.delete()
            plan = nil
            seenVersion = 0
            loadedStamp = store.updatedAt()
            onChange()
        } catch {
            saveFailed = true
        }
    }

    func markSeen() {
        guard let number = latestVersion?.number else { return }
        seenVersion = number
        store.markSeen(number)
    }

    func resolvedCategory(shortcut: TrainerRequestCategory?, text: String) -> TrainerRequestCategory {
        shortcut ?? TrainerEngine.classify(requestText: text)
    }

    private func migrateStrength() {
        guard var current = plan, current.strength.isEmpty, !store.strengthMigrated else { return }
        let detected = TrainerEngine.detectStrength(history: history, today: currentDay)
        guard !detected.isEmpty else { return }
        current.strength = detected
        persist(TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .strengthChanged))
        store.markStrengthMigrated()
    }

    private func applyPending() {
        guard var current = plan else { return }
        let triggers = TrainerEngine.pendingTriggers(current, history: history, today: currentDay)
        guard !triggers.isEmpty else { return }
        for trigger in triggers {
            current = TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: trigger)
        }
        persist(current)
    }

    private func persist(_ next: TrainerPlan) {
        plan = next
        do {
            try store.save(next)
            loadedStamp = store.updatedAt()
            saveFailed = false
            onChange()
        } catch {
            saveFailed = true
        }
    }

    private func loadHistory() async -> TrainerHistory {
        let container = container
        let day = currentDay
        return await Task.detached(priority: .utility) {
            TrainerHistoryLoader.load(container: container, today: day)
        }.value
    }

    private func row(_ workout: TrainerWorkout) -> TrainerDayRow {
        let result = TrainerEngine.status(of: workout, history: history, today: currentDay)
        let lines = plan.map { plan in
            TrainerEngine.strengthStatus(day: workout.day, plan: plan, history: history).map {
                TrainerStrengthLine(id: $0.session.id, name: $0.session.name, isDone: $0.done != nil)
            }
        } ?? []
        return TrainerDayRow(
            workout: workout, status: result.status, run: result.run, isChanged: changedDays.contains(workout.day), strength: lines
        )
    }
}
