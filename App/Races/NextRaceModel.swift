import Foundation
import Insights
import Metrics
import Observation
import Reports
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class NextRaceModel {
    typealias C = RacesConstants

    let raceId: UUID
    let today: Day
    @ObservationIgnored private let container: ModelContainer
    private(set) var info: RaceInfo?
    private(set) var outlook = TodaySummary.empty.race
    private(set) var target: StrategyTarget?
    private(set) var profile: [GPXPoint]?
    private(set) var manual: [Int: Double] = [:]
    private(set) var strategy: [KmPlan] = []
    private(set) var strategyState: StrategyState = .noTarget
    private(set) var block: [BlockWeek] = []
    private(set) var checklist: [ChecklistItem] = []
    private(set) var blockReading = ""
    private(set) var isLoaded = false

    init(container: ModelContainer, raceId: UUID, today: Day) {
        self.container = container
        self.raceId = raceId
        self.today = today
    }

    func load() async {
        let container = container
        let raceId = raceId
        let today = today
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(container: container, raceId: raceId, today: today)
        }.value
        guard !Task.isCancelled else { return }
        if let result {
            info = result.info
            outlook = result.outlook
            target = result.target
            profile = result.profile
            manual = result.manual
            block = result.block
            checklist = result.checklist
            blockReading = result.blockReading
            recalculate()
        }
        isLoaded = true
    }

    func setManualPace(_ pace: Double, at index: Int) {
        var updated = manual
        updated[index] = pace
        store(updated)
    }

    func releaseManualPace(at index: Int) {
        var updated = manual
        updated[index] = nil
        store(updated)
    }

    func clearManualPaces() {
        store([:])
    }

    var predictionContent: RacePredictionContent {
        RacePredictionContent(
            race: outlook,
            today: today,
            countdownDays: info.map { today.days(until: $0.day) },
            priority: info?.priority.rawValue,
            historyDays: TodayConstants.predictionHistoryDays
        )
    }

    var goalSummary: GoalSummary? {
        guard let info, let goal = info.goalSeconds, goal > 0 else { return nil }
        let reference: (Double, AssessmentReference)? = outlook.raceDay.map { ($0.mid, .raceDayProjection) }
            ?? outlook.today.map { ($0, .todayPrediction) }
        return GoalSummary(
            goalSeconds: goal,
            goalPaceText: RacesText.goalPaceText(goalSeconds: goal, distance: info.distance),
            todaySeconds: outlook.today,
            raceDaySeconds: outlook.raceDay?.mid,
            sentence: reference.flatMap { RacesText.assessmentSentence(goalSeconds: goal, referenceSeconds: $0.0, reference: $0.1) }
        )
    }

    var headerText: String? {
        info.map { RacesText.header(priority: $0.priority.rawValue, day: $0.day, today: today) }
    }

    var targetText: String? {
        guard let target else { return nil }
        let source = C.targetSources[target.source] ?? ""
        if target.source == .frozen, let day = target.frozenOn {
            return "\(C.targetPrefix) \(source) \(day.day)/\(day.month): \(TodayText.goalClock(target.seconds))"
        }
        return "\(C.targetPrefix): \(source) \(TodayText.goalClock(target.seconds))"
    }

    func elapsed(through index: Int) -> Double {
        guard let info else { return 0 }
        return strategy.prefix { $0.index <= index }.reduce(0) { $0 + $1.pace * kmLength($1.index, distance: info.distance) / C.metersPerKm }
    }

    private func kmLength(_ index: Int, distance: Double) -> Double {
        let kms = Int((distance / C.metersPerKm).rounded(.up))
        return index < kms - 1 ? C.metersPerKm : distance - Double(kms - 1) * C.metersPerKm
    }

    private func store(_ paces: [Int: Double]) {
        let context = container.mainContext
        let id = raceId
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let race = try? context.fetch(descriptor).first {
            race.manualPaces = paces
            race.updatedAt = .now
            try? context.save()
        }
        manual = paces
        recalculate()
    }

    private func recalculate() {
        guard let info, let target else {
            strategy = []
            strategyState = .noTarget
            return
        }
        strategy = paceStrategy(
            goalSeconds: target.seconds,
            distance: info.distance,
            profile: profile?.map { (distance: $0.distance, altitude: $0.altitude) },
            manual: manual
        )
        if strategy.isEmpty {
            strategyState = manual.isEmpty ? .noTarget : .infeasible
        } else {
            strategyState = profile == nil ? .noGPX : .ok
        }
    }

    nonisolated private static func compute(container: ModelContainer, raceId: UUID, today: Day) -> NextRaceLoad? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId })
        descriptor.fetchLimit = 1
        guard let race = (try? context.fetch(descriptor))?.first, let raceDay = Day(iso: race.day) else { return nil }
        let info = RaceInfo(
            id: race.id, name: race.name, day: raceDay, distance: race.distance, goalSeconds: race.goalSeconds,
            priority: race.priorityLevel, city: race.city, startTime: race.startTime
        )
        let efforts = (try? raceEfforts(context: context, today: today)) ?? []
        let outlook = raceOutlook(distance: race.distance, raceDay: raceDay, goalSeconds: race.goalSeconds, efforts: efforts, today: today)
        let target = (try? strategyTarget(race: race, outlook: outlook, today: today, context: context)) ?? nil
        let profile = race.gpxData.flatMap { try? gpxProfile($0) }.map { $0.map { GPXPoint(distance: $0.distance, altitude: $0.altitude) } }
        let block = raceBlock(raceDay: raceDay, today: today, weeklyKm: weeklyKm(context: context, raceDay: raceDay, today: today))
        let blockStart = block.first?.start ?? raceDay
        let longest = longestRun(context: context, since: blockStart, today: today)
        let longTarget = longRunTarget(raceDistance: race.distance)
        let pace = (race.goalSeconds ?? target?.seconds).map { $0 / (race.distance / C.metersPerKm) }
        return NextRaceLoad(
            info: info,
            outlook: outlook,
            target: target,
            profile: profile,
            manual: race.manualPaces,
            block: block,
            checklist: checklist(
                context: context, today: today, raceDay: raceDay, blockStart: blockStart,
                longest: longest, longTarget: longTarget, targetPace: pace
            ),
            blockReading: RacesText.blockReading(block: block, today: today, longestRun: longest, longRunTarget: longTarget)
        )
    }

    nonisolated private static func activities(context: ModelContext, since day: Day, today: Day) -> [ActivityRecord] {
        let lower = day.chartDate
        let upper = today.adding(days: 1).chartDate
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper })
        return ((try? context.fetch(descriptor)) ?? []).filter(\.hasStart)
    }

    nonisolated private static func runs(context: ModelContext, since day: Day, today: Day) -> [ActivityRecord] {
        activities(context: context, since: day, today: today).filter { ActivityTypeKey.isRun($0.typeKey) }
    }

    nonisolated private static func weeklyKm(context: ModelContext, raceDay: Day, today: Day) -> [Day: Double] {
        let blockStart = raceDay.weekStart.adding(days: -C.daysPerWeek * (C.blockWeeks - 1))
        let since = min(blockStart, today.weekStart.adding(days: -C.blockFetchExtraDays))
        var weeks: [Day: Double] = [:]
        for run in runs(context: context, since: since, today: today) {
            weeks[Day.today(now: run.start).weekStart, default: 0] += (run.distance ?? 0) / C.metersPerKm
        }
        return weeks
    }

    nonisolated private static func longestRun(context: ModelContext, since day: Day, today: Day) -> Double? {
        guard day <= today else { return nil }
        return runs(context: context, since: day, today: today).compactMap(\.distance).max()
    }

    nonisolated private static func checklist(
        context: ModelContext, today: Day, raceDay: Day, blockStart: Day,
        longest: Double?, longTarget: Double, targetPace: Double?
    ) -> [ChecklistItem] {
        func item(_ kind: ChecklistKind, _ detail: String?, ok: Bool) -> ChecklistItem {
            ChecklistItem(
                kind: kind,
                title: C.checklistTitles[kind] ?? "",
                detail: detail ?? C.checklistMissing[kind] ?? "",
                status: detail == nil ? .missing : (ok ? .ok : .attention)
            )
        }
        let vo2 = (try? metricSeries(.vo2max, context: context, today: today, period: C.checklistPeriod))?.points ?? []
        let vo2Now = vo2.last?.1
        let vo2Start = vo2.last { $0.0 <= blockStart }?.1 ?? vo2.first?.1
        let vo2Detail = vo2Now.flatMap { now in
            vo2Start.map { start in "\(TodayText.decimal(now, fractionDigits: 1)) hoje · \(TodayText.decimal(start, fractionDigits: 1)) no início (\(TodayText.signed(now - start, fractionDigits: 1)))" }
        }

        let longDetail = longest.map { "\(RacesText.km($0 / C.metersPerKm)) km de \(RacesText.km(longTarget / C.metersPerKm)) km" }

        let threshold = (try? metricSeries(.thresholdPace, context: context, today: today, period: C.checklistPeriod))?.stats.current
        let thresholdDetail = threshold.flatMap { value in
            targetPace.map { "limiar \(RacesText.paceText(value)) · alvo \(RacesText.paceText($0))" }
        }

        let iso = today.iso
        var dailyDescriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
        dailyDescriptor.fetchLimit = 1
        let daily = (try? context.fetch(dailyDescriptor))?.first
        let hrvDetail: String? = daily.flatMap { record in
            guard let value = record.hrvLastNight, let low = record.hrvBalancedLow, let high = record.hrvBalancedUpper else { return nil }
            return "\(Int(value.rounded())) ms · base \(Int(low.rounded()))–\(Int(high.rounded())) ms"
        }
        let hrvOK = daily.flatMap { record in record.hrvLastNight.flatMap { value in record.hrvBalancedLow.map { value >= $0 } } } ?? false

        let load = ReportBuilder(context: context, today: today)
            .dailyLoad(activities(context: context, since: today.adding(days: -C.loadHistoryDays), today: today))
        let form = load.isEmpty ? nil : fitnessOutlook(dailyLoad: load, today: today, raceDay: raceDay).raceDayForm

        return [
            item(.vo2max, vo2Detail, ok: (vo2Now ?? 0) >= (vo2Start ?? 0)),
            item(.longRun, longDetail, ok: (longest ?? 0) >= longTarget),
            item(.thresholdPace, thresholdDetail, ok: (threshold ?? .infinity) <= (targetPace ?? 0)),
            item(.hrv, hrvDetail, ok: hrvOK),
            item(.raceDayForm, form.map { "\(TodayText.signed($0)) \(C.raceDayLabel)" }, ok: (form ?? -1) >= 0),
        ]
    }
}
