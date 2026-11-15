import Foundation
import GarminAPI
import Insights
import Metrics
import Narrative
import Observation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class TodayModel {
    typealias C = TodayConstants

    let today: Day
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let snapshots: ScreenSnapshotStore?
    private(set) var summary: TodaySummary = .empty
    private(set) var readinessSentence = ""
    private(set) var readinessDay = ReadinessDay()
    private(set) var lastRun: LastRunSummary?
    private(set) var raceName: String?
    private(set) var weekRuns: [Day: [WeekRun]] = [:]
    private(set) var recoveryRun: RecoveryRun?
    private(set) var reportRuns: [ReportRun] = []
    private(set) var currentRuns: [ReportRun] = []
    private(set) var signals: [DailySignal] = []
    private(set) var planned: [Day: [PlannedWorkout]] = [:]
    private(set) var reportPlanned: [Day: [PlannedWorkout]] = [:]
    private(set) var plannedWeeks: [Day: Double] = [:]
    private(set) var garminReadiness: GarminReadinessScore?
    private(set) var goals: [GoalSnapshot] = []
    private(set) var isLoaded = false
    private(set) var isStale = false

    init(container: ModelContainer, today: Day, snapshots: ScreenSnapshotStore? = nil) {
        self.container = container
        self.today = today
        self.snapshots = snapshots
    }

    static func restored(container: ModelContainer, snapshots: ScreenSnapshotStore) async -> TodayModel? {
        guard let snapshot = await snapshots.read(TodaySnapshot.self, for: .today) else { return nil }
        let model = TodayModel(container: container, today: snapshot.today, snapshots: snapshots)
        model.apply(snapshot.load)
        model.isStale = true
        return model
    }

    func load() async {
        let container = container
        let today = today
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(container: container, today: today)
        }.value
        guard !Task.isCancelled else { return }
        apply(result)
        isStale = false
        await snapshots?.write(TodaySnapshot(today: today, load: result), for: .today)
    }

    private func apply(_ result: TodayLoad) {
        summary = result.summary
        readinessDay = result.readinessDay
        lastRun = result.lastRun
        raceName = result.raceName
        weekRuns = result.weekRuns
        recoveryRun = result.recoveryRun
        reportRuns = result.reportRuns
        currentRuns = result.currentRuns
        signals = result.signals
        goals = result.goals
        if let breakdown = result.summary.readiness, let verdict = result.summary.verdict {
            readinessSentence = TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
        }
        isLoaded = true
    }

    var todayPlan: PlannedWorkout? { planned[today]?.first }

    var fallbackScore: Int? {
        summary.readiness == nil ? garminReadiness?.score : nil
    }

    func loadGarminReadiness(client: GarminAccountClient?) async {
        garminReadiness = GarminReadinessCache.cached(day: today)
        guard summary.readiness == nil else { return }
        let score = await GarminReadinessCache.refresh(client: client, day: today)
        guard !Task.isCancelled else { return }
        garminReadiness = score
    }

    func loadPlanned(client: GarminAccountClient?) async {
        guard let client else { return }
        let first = today.weekStart
        let workouts: [PlannedWorkout]
        do {
            workouts = try await PlannedWorkouts.fetch(client: client, from: first, through: first.adding(days: 6))
        } catch {
            TodayConstants.logger.error("Falha ao buscar treinos planejados: \(String(describing: error), privacy: .public)")
            return
        }
        guard !Task.isCancelled else { return }
        planned = Dictionary(grouping: workouts) { Day(iso: $0.day) ?? today }
        guard let report = WeeklyReportBuilder.reportWeek(today: today), !report.isCurrent else { return }
        let previous = try? await PlannedWorkouts.fetch(client: client, from: report.start, through: report.start.adding(days: 6))
        guard !Task.isCancelled, let previous else { return }
        reportPlanned = Dictionary(grouping: previous) { Day(iso: $0.day) ?? report.start }
    }

    func plannedSessions(trainer: [TrainerWorkout] = []) -> [PlannedSession] {
        PlannedSessions.merge(garmin: (Array(planned.values) + Array(reportPlanned.values)).flatMap { $0 }, trainer: trainer)
    }

    func loadPlannedHistory(client: GarminAccountClient?, defaults: UserDefaults = .standard) async {
        guard let client else { return }
        let starts = summary.week.recentWeeks.map(\.start)
        let current = today.weekStart
        let currentPlanned = planned.values.flatMap { $0 }.compactMap(\.estimatedMeters).reduce(0, +) / WorkoutConstants.metersPerKilometer
        if currentPlanned > 0 { plannedWeeks[current] = currentPlanned }
        var cache = (defaults.dictionary(forKey: AppConstants.plannedWeeksDefaultsKey) as? [String: Double]) ?? [:]
        let missing = starts.filter { $0 < current && cache[$0.iso] == nil }
        if let first = missing.min(), let last = missing.max(),
           let workouts = try? await PlannedWorkouts.fetch(client: client, from: first, through: last.adding(days: 6)) {
            var totals = Dictionary(uniqueKeysWithValues: missing.map { ($0.iso, 0.0) })
            for workout in workouts {
                guard let start = Day(iso: workout.day)?.weekStart, totals[start.iso] != nil else { continue }
                totals[start.iso, default: 0] += (workout.estimatedMeters ?? 0) / WorkoutConstants.metersPerKilometer
            }
            cache.merge(totals) { _, new in new }
            defaults.set(cache, forKey: AppConstants.plannedWeeksDefaultsKey)
        }
        guard !Task.isCancelled else { return }
        var weeks: [Day: Double] = [:]
        for start in starts where start < current { weeks[start] = cache[start.iso] }
        if currentPlanned > 0 { weeks[current] = currentPlanned }
        plannedWeeks = weeks.filter { $0.value > 0 }
    }

    func refreshSentence() async {
        guard let breakdown = summary.readiness, let verdict = summary.verdict else { return }
        let sentence = await makeInsightNarrator().readinessSentence(breakdown, verdict: verdict)
        guard !Task.isCancelled, !sentence.isEmpty else { return }
        readinessSentence = sentence
    }

    var predictionContent: RacePredictionContent {
        RacePredictionContent(
            race: summary.race,
            today: today,
            countdownDays: summary.raceCountdownDays,
            priority: summary.racePriority?.rawValue,
            historyDays: C.predictionHistoryDays
        )
    }

    var raceTitle: String { summary.race.label }

    var raceDay: Day? {
        summary.raceCountdownDays.map { today.adding(days: $0) }
    }

    var goalSentence: String? { predictionContent.goalSentence }

    var readinessSummaryText: String? {
        summary.readiness.map { TodayText.readinessSummary(score: $0.score, normal: $0.normal) }
    }

    var factorRows: [ReadinessFactorRowData] {
        (summary.readiness?.factors ?? []).map(row)
    }

    var fitnessLines: [ChartLine] {
        let fitness = summary.fitness
        let history = fitness.history.suffix(C.fitnessHistoryDays)
        var lines = [
            ChartLine(name: "Fitness", colorKey: .fitness, dashed: false, points: history.map { ChartPoint(date: $0.day.chartDate, value: $0.fitness) }),
            ChartLine(name: "Forma", colorKey: .form, dashed: false, points: history.map { ChartPoint(date: $0.day.chartDate, value: $0.form) }),
        ]
        guard let last = history.last, !fitness.projection.isEmpty else { return lines }
        let projected = [last] + fitness.projection
        lines.append(ChartLine(name: "Fitness projetado", colorKey: .fitness, dashed: true, points: projected.map { ChartPoint(date: $0.day.chartDate, value: $0.fitness) }))
        lines.append(ChartLine(name: "Forma projetada", colorKey: .form, dashed: true, points: projected.map { ChartPoint(date: $0.day.chartDate, value: $0.form) }))
        return lines
    }

    private func row(_ factor: ReadinessFactor) -> ReadinessFactorRowData {
        let name = C.componentNames[factor.component] ?? factor.component.rawValue
        let raw = summary.readinessRaw[factor.component]
        guard factor.todayScore != nil else {
            return ReadinessFactorRowData(component: factor.component, name: name, detail: C.detailMissingValue, pointsText: nil, points: nil, group: .missing)
        }
        var parts: [String?] = [rawText(factor.component, raw?.today, includesLabel: true)]
        if factor.component == .sleep { parts.append(readinessDay.sleepSeconds.map(TodayText.sleepDuration)) }
        if let normal = raw?.normal, let text = rawText(factor.component, normal, includesLabel: false) {
            parts.append("seu normal \(text)")
        }
        if factor.component == .load { parts.append(C.loadIdealRange) }
        parts.append("peso \(Int((factor.weight * 100).rounded()))%")
        let group: ReadinessGroup = factor.points.map { $0 >= 0 ? .up : .down } ?? .baseline
        return ReadinessFactorRowData(
            component: factor.component,
            name: name,
            detail: parts.compactMap { $0 }.joined(separator: " · "),
            pointsText: factor.points.map { TodayText.signed($0, fractionDigits: 1) },
            points: factor.points,
            group: group
        )
    }

    private func rawText(_ component: ReadinessComponent, _ value: Double?, includesLabel: Bool) -> String? {
        guard let value else { return nil }
        switch component {
        case .hrv:
            return "\(Int(value.rounded())) ms"
        case .sleep:
            return includesLabel ? "nota \(Int(value.rounded()))" : "\(Int(value.rounded()))"
        case .bodyBattery:
            return "\(Int(value.rounded()))"
        case .load:
            let number = TodayText.decimal(value, fractionDigits: 2)
            return includesLabel ? "aguda:crônica \(number)" : number
        }
    }

    nonisolated private static func compute(container: ModelContainer, today: Day) -> TodayLoad {
        let context = ModelContext(container)
        try? freezeEveTargets(in: context, today: today)
        let summary = (try? todaySummary(context: context, today: today)) ?? .empty
        return TodayLoad(
            summary: summary,
            readinessDay: readinessDay(context: context, today: today, summary: summary),
            lastRun: lastRun(context: context, id: summary.lastRunId),
            raceName: (try? targetRace(in: context, today: today))?.name,
            weekRuns: weekRuns(context: context, today: today),
            recoveryRun: recoveryRun(context: context),
            reportRuns: WeeklyReportBuilder.reportWeek(today: today).map { reportRuns(context: context, start: $0.start) } ?? [],
            currentRuns: reportRuns(context: context, start: today.weekStart),
            signals: signals(context: context, today: today),
            goals: (try? goalSnapshots(context: context, today: today)) ?? []
        )
    }

    var overload: OverloadAlert? {
        OverloadDetector.alert(signals, today: today, ratio: summary.supporting.acuteChronic)
    }

    nonisolated private static func signals(context: ModelContext, today: Day) -> [DailySignal] {
        let first = today.adding(days: -(OverloadConstants.recentDays + OverloadConstants.baselineDays)).iso
        let last = today.iso
        let descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day >= first && $0.day <= last })
        return ((try? context.fetch(descriptor)) ?? []).compactMap { record in
            Day(iso: record.day).map { DailySignal(day: $0, restingHeartRate: record.restingHR, hrv: record.hrvLastNight) }
        }
    }

    func weeklyReport(trainer: [TrainerWorkout] = []) -> WeeklyReport? {
        guard let week = WeeklyReportBuilder.reportWeek(today: today) else { return nil }
        return WeeklyReportBuilder.report(
            start: week.start, isCurrent: week.isCurrent, runs: reportRuns, plannedKm: plannedWeeks[week.start], race: race,
            sessions: plannedSessions(trainer: trainer), today: today
        )
    }

    func currentWeekReport(trainer: [TrainerWorkout] = []) -> WeeklyReport {
        WeeklyReportBuilder.report(
            start: today.weekStart, isCurrent: true, runs: currentRuns, plannedKm: plannedWeeks[today.weekStart], race: race,
            sessions: plannedSessions(trainer: trainer), today: today
        )
    }

    func lastRunPlannedKm(trainer: [TrainerWorkout] = []) -> Double? {
        guard let day = lastRun?.day else { return nil }
        let km = plannedSessions(trainer: trainer).filter { $0.day == day }.reduce(0) { $0 + $1.kilometers }
        return km > 0 ? km : nil
    }

    private var race: ReportRace? {
        guard let name = raceName, let days = summary.raceCountdownDays else { return nil }
        return WeeklyReportBuilder.race(name: name, days: days, today: today, predictionSeconds: summary.race.raceDay?.mid ?? summary.race.today)
    }

    nonisolated private static func reportRuns(context: ModelContext, start: Day) -> [ReportRun] {
        let lower = start.chartDate
        let upper = start.adding(days: 7).chartDate
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        return ((try? context.fetch(descriptor)) ?? []).filter { ActivityTypeKey.isRun($0.typeKey) }.map { record in
            ReportRun(
                title: record.workoutName ?? record.name,
                kilometers: (record.distance ?? 0) / WorkoutConstants.metersPerKilometer,
                score: record.scoreValue,
                day: record.localDay ?? Day.today(now: record.start).iso,
                kind: LastRunBuilder.kind(of: record),
                paceSeconds: LastRunBuilder.paceSeconds(record)
            )
        }
    }

    nonisolated private static func recoveryRun(context: ModelContext) -> RecoveryRun? {
        let since = Date.now.addingTimeInterval(-Double(RecoveryConstants.hourWindowDays) * RecoveryConstants.secondsPerDay)
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= since }, sortBy: [SortDescriptor(\.start, order: .reverse)])
        let runs = ((try? context.fetch(descriptor)) ?? []).filter { ActivityTypeKey.isRun($0.typeKey) && $0.hasStart }
        guard let last = runs.first else { return nil }
        let hours = RecoveryEstimator.typicalHours(runs.map(\.start))
        return RecoveryRun(
            title: last.workoutName ?? last.name,
            end: last.start.addingTimeInterval(last.duration ?? last.movingDuration ?? 0),
            aerobicEffect: last.aerobicTrainingEffect,
            anaerobicEffect: last.anaerobicTrainingEffect,
            typicalHour: hours.weekday,
            weekendHour: hours.weekend,
            kind: LastRunBuilder.kind(of: last),
            kilometers: last.distance.map { $0 / WorkoutConstants.metersPerKilometer },
            averageHeartRate: last.averageHR.map { Int($0.rounded()) }
        )
    }

    nonisolated private static func weekRuns(context: ModelContext, today: Day) -> [Day: [WeekRun]] {
        let start = today.weekStart.chartDate
        let end = today.adding(days: 1).chartDate
        let descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start >= start && $0.start < end },
            sortBy: [SortDescriptor(\.start)]
        )
        let records = ((try? context.fetch(descriptor)) ?? []).filter { ActivityTypeKey.isRun($0.typeKey) }
        var result: [Day: [WeekRun]] = [:]
        for record in records {
            let total = record.zoneSeconds.reduce(0, +)
            let run = WeekRun(
                activityId: record.activityId,
                title: record.workoutName ?? record.name,
                kilometers: (record.distance ?? 0) / WorkoutConstants.metersPerKilometer,
                score: record.scoreValue,
                zoneShares: total > 0 ? record.zoneSeconds.map { $0 / total } : []
            )
            result[Day.today(now: record.start), default: []].append(run)
        }
        return result
    }

    nonisolated private static func readinessDay(context: ModelContext, today: Day, summary: TodaySummary) -> ReadinessDay {
        let iso = today.iso
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
        descriptor.fetchLimit = 1
        let record = (try? context.fetch(descriptor))?.first
        return ReadinessDay(sleepSeconds: record?.sleepSeconds, stress: summary.supporting.stress)
    }

    nonisolated private static func lastRun(context: ModelContext, id: Int64?) -> LastRunSummary? {
        guard let id else { return nil }
        var target = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })
        target.fetchLimit = 1
        guard let record = (try? context.fetch(target))?.first else { return nil }
        let records = comparisonRecords(context: context, around: record)
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        let hasComparison = analysis.comparison != nil && !analysis.comparisonRows.isEmpty
        let reading = hasComparison
            ? WorkoutReading.resolve(stored: record.narrativeData, assessment: analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
            : nil
        let kilometers = record.distance.map { $0 / WorkoutConstants.metersPerKilometer }
        let similar = LastRunBuilder.similar(to: record, among: records)
        let detailed = detailedAnalysis(record: record, history: records, daily: [])
        let dayIso = record.localDay ?? Day.today(now: record.start).iso
        let readiness = readinessScore(context: context, day: dayIso)
        let kind = LastRunBuilder.kind(of: record)
        let paceSeconds = LastRunBuilder.paceSeconds(record)
        let zoneTotal = record.zoneSeconds.reduce(0, +)
        return LastRunSummary(
            activityId: id,
            title: record.workoutName ?? record.name,
            dateText: WorkoutListModel.dateText(record.start),
            kilometers: kilometers,
            paceSeconds: paceSeconds,
            averageHeartRate: record.averageHR.map { Int($0.rounded()) },
            evolution: reading?.evolution,
            evolutionOnDevice: reading?.evolutionOnDevice ?? false,
            notice: hasComparison ? analysis.comparisonNotice : nil,
            score: record.scoreValue ?? analysis.score?.value,
            day: Day(iso: dayIso),
            kind: kind,
            place: record.locationName,
            durationText: LastRunBuilder.duration(seconds: record.movingDuration ?? record.duration),
            elevationGain: record.elevationGain,
            splits: detailed?.splits.map { LastRunSplit(km: $0.km, paceSeconds: $0.paceSeconds, heartRate: $0.heartRate) },
            fadeKm: detailed?.fadeKm,
            zoneShares: zoneTotal > 0 ? record.zoneSeconds.map { $0 / zoneTotal } : nil,
            heartRateHigh: LastRunBuilder.isHeartRateHigh(current: record.averageHR, similar: similar.compactMap(\.averageHR)),
            similar: similar.map(similarRun),
            reading: LastRunBuilder.reading(
                kind: kind,
                paceSeconds: paceSeconds,
                averageHeartRate: record.averageHR.map { Int($0.rounded()) },
                fadeKm: detailed?.fadeKm,
                readiness: readiness,
                reference: similar.first.map {
                    LastRunReference(dateText: LastRunBuilder.shortDate($0.start), paceSeconds: LastRunBuilder.paceSeconds($0), averageHeartRate: $0.averageHR.map { Int($0.rounded()) })
                }
            )
        )
    }

    nonisolated private static func similarRun(_ record: ActivityRecord) -> LastRunSimilar {
        LastRunSimilar(
            activityId: record.activityId,
            dateText: LastRunBuilder.dateText(record.start),
            kilometers: (record.distance ?? 0) / WorkoutConstants.metersPerKilometer,
            elevationGain: record.elevationGain,
            paceSeconds: LastRunBuilder.paceSeconds(record),
            averageHeartRate: record.averageHR.map { Int($0.rounded()) }
        )
    }

    nonisolated private static func readinessScore(context: ModelContext, day: String) -> Int? {
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.readinessScore
    }

    nonisolated private static func comparisonRecords(context: ModelContext, around record: ActivityRecord) -> [ActivityRecord] {
        let start = record.start
        let windowStart = start.addingTimeInterval(-TodayConstants.comparisonWindowDays * WorkoutDetailConstants.secondsPerDay)
        var recent = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start >= windowStart && $0.start <= start },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        recent.fetchLimit = TodayConstants.comparisonFetchLimit
        var records = (try? context.fetch(recent)) ?? []
        if let name = record.workoutName {
            var named = FetchDescriptor<ActivityRecord>(
                predicate: #Predicate { $0.workoutName == name && $0.start <= start },
                sortBy: [SortDescriptor(\.start, order: .reverse)]
            )
            named.fetchLimit = WorkoutDetailConstants.maxComparisons + 1
            let known = Set(records.map(\.activityId))
            records += ((try? context.fetch(named)) ?? []).filter { !known.contains($0.activityId) }
        }
        return records.sorted { $0.start > $1.start }
    }
}
