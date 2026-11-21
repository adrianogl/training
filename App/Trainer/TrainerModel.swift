import Foundation
import GarminAPI
import Insights
import Metrics
import Observation
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class TrainerModel {
    private(set) var plan: TrainerPlan? { didSet { reviewCache = nil } }
    private(set) var history = TrainerHistory(runs: [])
    private(set) var cycleHistory = TrainerHistory(runs: []) { didSet { reviewCache = nil } }
    private(set) var seenVersion: Int
    private(set) var isLoaded = false
    private(set) var isWorking = false
    var isSendingToGarmin = false
    private(set) var isAdjusting = false
    private(set) var saveFailed = false
    private(set) var externalWorkouts: [TrainerExternalWorkout] = []
    private(set) var standaloneStrength: [TrainerStrengthSession] = []
    private(set) var strengthPlan: StrengthPlan?
    private(set) var dismissedMigrationPlanId: String?
    private(set) var keptReadinessDay: String?
    private(set) var seenCycleEnd: Day?
    private(set) var cycleSummaries: [TrainerCycleSummary]

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let store: TrainerStore
    @ObservationIgnored private let today: @Sendable () -> Day
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let signalNotifier: TrainerSignalNotifier
    @ObservationIgnored let strengthPlanStore: StrengthPlanStore
    @ObservationIgnored let planEndScheduler: any NotificationScheduling
    @ObservationIgnored let canNotifyPlanEnd: Bool
    @ObservationIgnored let claudeStore: ClaudeStrengthStore
    @ObservationIgnored private var autoTask: Task<Void, Never>?
    @ObservationIgnored private var settleWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var loadedStamp: Date?
    @ObservationIgnored private var reviewCache: (day: Day, review: TrainerCycleReview?)?
    @ObservationIgnored var onChange: @MainActor () -> Void = {}

    init(
        container: ModelContainer, store: TrainerStore = TrainerStore(), today: @escaping @Sendable () -> Day = { Day.today() },
        defaults: UserDefaults = AccountScope.current.defaults, signalNotifier: TrainerSignalNotifier? = nil,
        strengthPlanStore: StrengthPlanStore = StrengthPlanStore(), claudeStore: ClaudeStrengthStore = ClaudeStrengthStore(),
        planEndScheduler: any NotificationScheduling = UserNotificationScheduler(),
        canNotifyPlanEnd: Bool = StrengthPlanEndNotifier.runsOnPhone
    ) {
        self.canNotifyPlanEnd = canNotifyPlanEnd
        self.planEndScheduler = planEndScheduler
        self.strengthPlanStore = strengthPlanStore
        self.claudeStore = claudeStore
        self.strengthPlan = strengthPlanStore.current()
        self.container = container
        self.store = store
        self.today = today
        self.defaults = defaults
        self.signalNotifier = signalNotifier ?? TrainerSignalNotifier(defaults: defaults)
        self.keptReadinessDay = defaults.string(forKey: TrainerConstants.readinessKeptDefaultsKey)
        self.dismissedMigrationPlanId = defaults.string(forKey: StrengthPlanUIConstants.migrationDismissedKey)
        self.seenVersion = store.seenVersion
        self.seenCycleEnd = store.seenCycleEnd
        self.cycleSummaries = store.cycleSummaries()
        self.plan = store.load()
        self.loadedStamp = store.updatedAt()
    }

    var currentDay: Day { today() }

    var latestVersion: TrainerVersion? { plan?.versions.last }

    var cycleReview: TrainerCycleReview? {
        let day = currentDay
        let plan = plan
        let cycleHistory = cycleHistory
        if let cache = reviewCache, cache.day == day { return cache.review }
        let review = plan.flatMap { TrainerEngine.cycleReview(plan: $0, history: cycleHistory, today: day) }
        reviewCache = (day, review)
        return review
    }

    private var isActive: Bool { plan?.endedOn == nil }

    var hasActivePlan: Bool { plan != nil && isActive }

    var activeWorkouts: [TrainerWorkout] {
        guard let plan else { return [] }
        if let endedOn = plan.endedOn { return plan.workouts.filter { $0.day <= endedOn } }
        if let date = plan.target.date, currentDay > date { return plan.workouts.filter { $0.day <= date } }
        return plan.workouts
    }

    func todayRow(for day: Day) -> TrainerDayRow? {
        guard isActive else { return nil }
        return row(for: day.iso)
    }

    var showsCycleBanner: Bool {
        guard let review = cycleReview else { return false }
        guard let seen = seenCycleEnd else { return true }
        return review.last > seen
    }

    var cycleEnded: Bool {
        guard let plan else { return false }
        if plan.endedOn != nil { return true }
        guard let date = plan.target.date else { return false }
        return currentDay > date || cycleReview != nil
    }

    var finishedWeekCount: Int {
        let now = currentDay
        return plan?.weeks.filter { $0.start.adding(days: TrainerConstants.weekdayCount) <= now }.count ?? 0
    }

    func endCycle() async {
        guard var current = plan, current.endedOn == nil else { return }
        isWorking = true
        defer { isWorking = false }
        current.endedOn = currentDay
        persist(current)
        cycleHistory = await loadCycleHistory()
    }

    func markCycleSeen() {
        guard let review = cycleReview else { return }
        seenCycleEnd = review.last
        store.markCycleSeen(review.last)
    }

    func suggestedVolumes() -> (start: Int, peak: Int)? {
        guard let review = cycleReview else { return nil }
        return Self.kilometers(start: review.suggestedStartMeters, peak: review.suggestedPeakMeters)
    }

    func cycleVolumes() -> (start: Int, peak: Int)? {
        guard let review = cycleReview else { return nil }
        return Self.kilometers(start: review.currentStartMeters, peak: review.currentPeakMeters)
    }

    private static func kilometers(start: Double, peak: Double) -> (start: Int, peak: Int) {
        (
            Int((start / TrainerConstants.metersPerKilometer).rounded()),
            Int((peak / TrainerConstants.metersPerKilometer).rounded())
        )
    }

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
        guard let plan, plan.endedOn == nil, let score, keptReadinessDay != currentDay.iso else { return nil }
        var seen = history
        seen.readiness[currentDay] = score
        return TrainerEngine.readinessSuggestion(plan: plan, history: seen, today: currentDay, factor: factor)
    }

    func reloadKeptReadiness() {
        keptReadinessDay = defaults.string(forKey: TrainerConstants.readinessKeptDefaultsKey)
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
                detail: Self.isLight(week.start, in: plan)
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
                isLight: Self.isLight(week.start, in: plan)
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

    func raceOption(id: String) -> TrainerRaceOption? {
        let races = (try? container.mainContext.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? []
        guard let race = races.first(where: { $0.id.uuidString == id }), let day = Day(iso: race.day) else { return nil }
        return TrainerRaceOption(id: race.id, name: race.name, day: day, distance: race.distance, goalSeconds: race.goalSeconds)
    }

    func previewStrength() -> [TrainerStrengthSession] {
        TrainerEngine.detectStrength(history: history, today: currentDay)
    }

    func strengthRows() -> [TrainerStrengthRow] {
        guard let plan else { return [] }
        let now = currentDay
        let since = now.adding(days: -TrainerConstants.strengthWeeks * TrainerConstants.weekdayCount)
        return plan.strength.sorted { $0.weekday < $1.weekday }.map { session in
            let scoped = Self.strengthHistory(history, for: session, plan: strengthPlan)
            let seconds = scoped.strength
                .filter { $0.day > since && $0.day <= now && $0.day.weekStart.days(until: $0.day) + 1 == session.weekday }
                .map(\.seconds)
            let minutes = seconds.isEmpty ? nil : Int((seconds.reduce(0, +) / Double(seconds.count) / 60).rounded())
            let done = TrainerEngine.strengthWeeksDone(session, history: scoped, today: now)
            return TrainerStrengthRow(session: session, caption: TrainerText.strengthCaption(done: done, minutes: minutes))
        }
    }

    func saveStrength(_ sessions: [TrainerStrengthSession]) async {
        let trainer = sessions.filter { $0.source == .trainer }
        if var current = strengthPlan {
            guard current.sessions != trainer else { return await applyStrength(sessions) }
            current.sessions = trainer
            return await saveStrengthPlan(current, mfit: sessions.filter { $0.source == .mfit })
        }
        if !trainer.isEmpty, var created = StrengthPlanMigration.migrate(sessions: trainer, runningPlanEnd: runningPlanEndForStrength, today: currentDay) {
            created.migrated = false
            try? strengthPlanStore.save(created)
            strengthPlan = strengthPlanStore.current()
        }
        await applyStrength(sessions)
    }

    func saveStrengthPlan(_ updated: StrengthPlan) async {
        await saveStrengthPlan(updated, mfit: legacyStrengthSessions.filter { $0.source == .mfit })
    }

    private func saveStrengthPlan(_ edited: StrengthPlan, mfit: [TrainerStrengthSession]) async {
        var updated = edited
        if let previous = strengthPlanStore.current() ?? strengthPlan {
            let left = previous.id == updated.id
                ? Self.changedWeekdays(from: previous.sessions, to: updated.sessions)
                : Set(previous.sessions.map(\.weekday))
            claudeStore.removePlanWeekdays(left, planId: previous.id)
            if previous.id == updated.id {
                let moved = previous.end != updated.end || previous.lastSessionDay() != updated.lastSessionDay()
                updated.endedNotifiedAt = moved ? nil : previous.endedNotifiedAt ?? updated.endedNotifiedAt
            }
        }
        try? strengthPlanStore.save(updated)
        strengthPlan = strengthPlanStore.current()
        await applyStrength(mfit + updated.sessions.filter { $0.source == .trainer })
        await checkStrengthPlanEnd()
    }

    func endStrengthPlan() async {
        if let previous = strengthPlanStore.current() ?? strengthPlan {
            claudeStore.removePlanWeekdays(previous.weekdays, planId: previous.id)
        }
        try? strengthPlanStore.clear()
        strengthPlan = strengthPlanStore.current()
        await applyStrength(legacyStrengthSessions.filter { $0.source == .mfit })
        await checkStrengthPlanEnd()
    }

    var showsStrengthMigrationNotice: Bool {
        guard let strengthPlan, strengthPlan.migrated else { return false }
        return dismissedMigrationPlanId != strengthPlan.id.uuidString
    }

    func dismissStrengthMigrationNotice() {
        guard let strengthPlan else { return }
        dismissedMigrationPlanId = strengthPlan.id.uuidString
        defaults.set(dismissedMigrationPlanId, forKey: StrengthPlanUIConstants.migrationDismissedKey)
    }

    private static func changedWeekdays(from old: [TrainerStrengthSession], to new: [TrainerStrengthSession]) -> Set<Int> {
        let before = Dictionary(old.filter { $0.source == .trainer }.map { ($0.weekday, $0.group) }, uniquingKeysWith: { first, _ in first })
        let after = Dictionary(new.filter { $0.source == .trainer }.map { ($0.weekday, $0.group) }, uniquingKeysWith: { first, _ in first })
        return Set(before.keys.filter { after[$0] != before[$0] })
    }

    private var runningPlanEndForStrength: Day? {
        plan.flatMap { $0.endedOn == nil ? Self.runningPlanEnd($0) : nil }
    }

    private func applyStrength(_ sessions: [TrainerStrengthSession]) async {
        guard var current = plan else {
            standaloneStrength = sessions.sorted { $0.weekday < $1.weekday }
            TrainerStrengthStandaloneStore().save(standaloneStrength)
            return
        }
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        current.strength = sessions
        let adjusted = TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .strengthChanged)
        persist(adjusted)
        store.markStrengthMigrated()
        markSeen()
    }

    func syncStrength(_ sessions: [TrainerStrengthSession]) async {
        let current = strengthSessions
        guard !sessions.isEmpty, !StrengthSessions.sameMFIT(sessions, current) else { return }
        let trainer = strengthPlan?.sessions.filter { $0.source == .trainer } ?? legacyStrengthSessions.filter { $0.source == .trainer }
        await applyStrength(StrengthSessions.merge(mfit: sessions, into: []) + trainer)
    }

    func legSwapSuggestion(kept: Set<String>) -> TrainerLegSwap? {
        guard let plan else { return nil }
        return TrainerLegSwapFinder.find(plan: plan, today: currentDay, kept: kept)
    }

    func applyLegSwap(_ swap: TrainerLegSwap) {
        guard let plan else { return }
        persist(TrainerLegSwapFinder.apply(swap, to: plan, now: .now))
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

    var easyPaceBand: PaceBand? {
        TrainerEngine.easyPaceBand(plan: plan, history: history, today: currentDay)
    }

    func timeEstimate(_ workout: TrainerWorkout, run: TrainerRun?) -> RunTimeRange? {
        guard run == nil, workout.day >= currentDay else { return nil }
        return TrainerEngine.timeEstimate(workout, fallback: easyPaceBand)
    }

    func previewPaces() -> TrainerPaces {
        TrainerEngine.paces(history: history, today: currentDay)
    }

    func reloadStrengthPlan() {
        let latest = strengthPlanStore.current()
        if latest != strengthPlan { strengthPlan = latest }
    }

    func reloadFromStore() {
        let stamp = store.updatedAt()
        guard stamp != loadedStamp else { return }
        loadedStamp = stamp
        plan = store.load()
        strengthPlan = strengthPlanStore.current()
        seenVersion = store.seenVersion
        fillMissingWeeks()
    }

    func load() async {
        plan = store.load()
        standaloneStrength = TrainerStrengthStandaloneStore().load()
        loadedStamp = store.updatedAt()
        history = await loadHistory()
        if plan != nil { cycleHistory = await loadCycleHistory() }
        isLoaded = true
        fillMissingWeeks()
        migrateStrength()
        migrateStrengthPlan()
        await notifySignals(applyPending())
        await checkStrengthPlanEnd()
    }

    func scheduleAutoAdjust() {
        autoTask?.cancel()
        isAdjusting = true
        autoTask = Task { [weak self] in
            await self?.autoAdjust()
            self?.isAdjusting = false
        }
    }

    func cancelAutoAdjust() {
        autoTask?.cancel()
        autoTask = nil
        isAdjusting = false
        resumeSettling()
    }

    func settleAutoAdjust() async {
        while !Task.isCancelled, let task = autoTask {
            await withCheckedContinuation { continuation in
                settleWaiters.append(continuation)
                Task { @MainActor [weak self] in
                    await task.value
                    if self?.autoTask == task { self?.autoTask = nil }
                    self?.resumeSettling()
                }
            }
        }
    }

    private func resumeSettling() {
        let waiters = settleWaiters
        settleWaiters = []
        waiters.forEach { $0.resume() }
    }

    @discardableResult
    func autoAdjust() async -> [TrainerVersion] {
        reloadFromStore()
        guard plan != nil else { return [] }
        let loaded = await loadHistory()
        guard !Task.isCancelled else { return [] }
        history = loaded
        let cycle = await loadCycleHistory()
        guard !Task.isCancelled else { return [] }
        cycleHistory = cycle
        reloadFromStore()
        guard !Task.isCancelled else { return [] }
        let created = applyPending()
        await notifySignals(created)
        await checkStrengthPlanEnd()
        return created
    }

    func isLightWeek(_ start: Day) -> Bool { plan.map { Self.isLight(start, in: $0) } == true }

    private static func isLight(_ start: Day, in plan: TrainerPlan) -> Bool {
        plan.lightWeeks.contains(start) || plan.earlyLightWeeks[start] != nil
    }

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
        peakMeters: Double?, lightWeeks: [Day] = [], longMode: TrainerLongMode = .continuous, dayPreference: TrainerDayPreference? = nil,
        paceOverrides: [TrainerPaceKind: Double] = [:]
    ) async {
        isWorking = true
        defer { isWorking = false }
        history = await loadHistory()
        if plan != nil { cycleHistory = await loadCycleHistory() }
        let previous = plan
        let review = cycleReview
        let created = TrainerEngine.create(
            target: target, structure: structure, strength: strength.isEmpty ? standaloneStrength : strength, history: history, today: currentDay, now: .now,
            startMeters: startMeters, peakMeters: peakMeters, lightWeeks: lightWeeks, longMode: longMode, dayPreference: dayPreference,
            paceOverrides: paceOverrides
        )
        archiveCycle(previous, review: review, afterPeakMeters: TrainerEngine.volumes(of: created, history: history, today: currentDay).peak)
        persist(created)
        cycleHistory = history
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
        paceOverrides: [TrainerPaceKind: Double], dayPreference: TrainerDayPreference? = nil
    ) -> TrainerEdit? {
        guard let plan else { return nil }
        return TrainerEngine.makeEdit(
            for: plan, target: target, startMeters: startMeters, peakMeters: peakMeters, structure: structure, strength: plan.strength,
            longMode: longMode, paceOverrides: paceOverrides, history: history, today: currentDay, dayPreference: dayPreference
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

    private func archiveCycle(_ previous: TrainerPlan?, review: TrainerCycleReview?, afterPeakMeters: Double) {
        guard let previous, let review, !review.weeks.isEmpty else { return }
        store.archive(TrainerCycleSummary(
            title: TrainerText.targetTitle(previous.target), first: review.first, last: review.last, verdict: review.verdict,
            beforePeakMeters: review.currentPeakMeters, afterPeakMeters: afterPeakMeters, resultSeconds: review.raceSeconds
        ))
        cycleSummaries = store.cycleSummaries()
    }

    private func fillMissingWeeks() {
        guard let current = plan, current.endedOn == nil,
              let filled = TrainerEngine.fillMissingWeeks(current, history: history, today: currentDay) else { return }
        persist(filled)
    }

    func migrateStrengthPlan() {
        _ = try? strengthPlanStore.migrateIfNeeded(sessions: legacyStrengthSessions, runningPlanEnd: runningPlanEndForStrength, today: currentDay)
        strengthPlan = strengthPlanStore.current()
    }

    private static func runningPlanEnd(_ plan: TrainerPlan) -> Day? {
        plan.target.date ?? plan.weeks.last.map { $0.start.adding(days: 6) }
    }

    private func migrateStrength() {
        guard var current = plan, current.endedOn == nil, current.strength.isEmpty, !store.strengthMigrated else { return }
        let detected = TrainerEngine.detectStrength(history: history, today: currentDay)
        guard !detected.isEmpty else { return }
        current.strength = detected
        persist(TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: .strengthChanged))
        store.markStrengthMigrated()
    }

    private func applyPending() -> [TrainerVersion] {
        guard var current = plan, current.endedOn == nil else { return [] }
        let triggers = TrainerEngine.pendingTriggers(current, history: history, today: currentDay)
        guard !triggers.isEmpty else { return [] }
        let previous = current.versions.last?.number ?? 0
        for trigger in triggers {
            current = TrainerEngine.adjust(current, history: history, today: currentDay, now: .now, trigger: trigger)
        }
        persist(current)
        return current.versions.filter { $0.number > previous }
    }

    private func notifySignals(_ created: [TrainerVersion]) async {
        guard !created.isEmpty, let plan else { return }
        await signalNotifier.notify(created, plan: plan)
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

    private func loadCycleHistory() async -> TrainerHistory {
        await loadHistory(since: plan?.weeks.map(\.start).min())
    }

    private func loadHistory(since: Day? = nil) async -> TrainerHistory {
        let container = container
        let day = currentDay
        return await Task.detached(priority: .utility) {
            TrainerHistoryLoader.load(container: container, today: day, since: since)
        }.value
    }

    private func row(_ workout: TrainerWorkout) -> TrainerDayRow {
        let result = TrainerEngine.status(of: workout, history: history, today: currentDay)
        var lines = plan.map { plan in
            TrainerEngine.strengthStatus(day: workout.day, plan: plan, history: history).map {
                TrainerStrengthLine(id: $0.session.id, name: $0.session.name, isDone: $0.done != nil, source: $0.session.source)
            }
        } ?? []
        let freeClaude = isFreeClaudeDay(workout.day)
        lines = lines.filter { $0.source == .mfit || isStrengthPlanActive(on: workout.day) }.map { line in
            var copy = line
            copy.isClaude = freeClaude && line.source == .trainer
            return copy
        }
        if let override = claudeOverride(on: workout.day) {
            let done = history.strength.contains { $0.day == workout.day }
            lines = [TrainerStrengthLine(id: override.id, name: override.name, isDone: done, source: .trainer, isClaude: true)]
        }
        return TrainerDayRow(
            workout: workout, status: result.status, run: result.run, isChanged: changedDays.contains(workout.day), strength: lines,
            longStage: workout.day == nextLongDay ? plan?.longStage : nil, estimate: timeEstimate(workout, run: result.run)
        )
    }

    private var nextLongDay: Day? {
        plan?.workouts.filter { $0.kind == .long && $0.day >= currentDay }.map(\.day).min()
    }
}
