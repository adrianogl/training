import FITReader
import Foundation
import Metrics
import Observation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class RaceListModel {
    typealias C = RacesConstants

    let today: Day
    @ObservationIgnored private let container: ModelContainer
    private(set) var upcoming: [RaceRowData] = []
    private(set) var completed: [RaceRowData] = []
    private(set) var summaries: [UUID: CompletedRaceSummary] = [:]
    private(set) var isLoaded = false

    init(container: ModelContainer, today: Day) {
        self.container = container
        self.today = today
    }

    func load() async {
        let container = container
        let today = today
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(container: container, today: today)
        }.value
        guard !Task.isCancelled else { return }
        upcoming = result.upcoming
        completed = result.completed
        summaries = result.summaries
        isLoaded = true
    }

    func linkResult(raceId: UUID, activityId: Int64) {
        let context = container.mainContext
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId })
        descriptor.fetchLimit = 1
        guard let race = try? context.fetch(descriptor).first else { return }
        race.resultActivityId = activityId
        race.manuallyUnlinked = false
        race.updatedAt = .now
        try? context.save()
    }

    func unlinkResult(raceId: UUID) {
        let context = container.mainContext
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId })
        descriptor.fetchLimit = 1
        guard let race = try? context.fetch(descriptor).first else { return }
        race.resultActivityId = nil
        race.manuallyUnlinked = true
        race.updatedAt = .now
        try? context.save()
    }

    func resultOptions(for raceId: UUID) async -> [ResultOption] {
        let container = container
        return await Task.detached(priority: .userInitiated) {
            Self.options(container: container, raceId: raceId)
        }.value
    }

    nonisolated private static func options(container: ModelContainer, raceId: UUID) -> [ResultOption] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == raceId })
        descriptor.fetchLimit = 1
        guard let race = (try? context.fetch(descriptor))?.first, let day = Day(iso: race.day) else { return [] }
        let lower = day.adding(days: -C.pickerWindowDays).chartDate
        let upper = day.adding(days: C.pickerWindowDays + 1).chartDate
        let records = ((try? context.fetch(FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start >= lower && $0.start < upper },
            sortBy: [SortDescriptor(\.start)]
        ))) ?? []).filter { $0.hasStart && ActivityTypeKey.isRun($0.typeKey) }
        return records.map { record in
            ResultOption(
                activityId: record.activityId,
                title: record.workoutName ?? record.name,
                dateText: WorkoutListModel.dateText(record.start),
                distanceText: record.distance.map(WorkoutListModel.distanceText) ?? "—",
                durationText: record.duration.map(WorkoutFormat.clock) ?? "—",
                isLinked: record.activityId == race.resultActivityId
            )
        }
    }

    nonisolated private static func compute(container: ModelContainer, today: Day) -> RaceListLoad {
        let context = ModelContext(container)
        let races = ((try? context.fetch(FetchDescriptor<RaceRecord>())) ?? [])
            .compactMap { race in Day(iso: race.day).map { (race, $0) } }
            .sorted { $0.1 < $1.1 }
        let upcomingRaces = races.filter { $0.1 >= today }
        let pastRaces = races.filter { $0.1 < today }
        let linked = Set(races.compactMap { $0.0.resultActivityId })
        let candidates = resultCandidates(context: context, days: Set(pastRaces.map(\.1)), linked: linked)

        var summaries: [UUID: CompletedRaceSummary] = [:]
        var bestByDistance: [(distance: Double, seconds: Double)] = []
        for (race, day) in pastRaces {
            let info = info(race, day: day)
            let linkedCandidate = race.resultActivityId.flatMap { id in candidates.byId[id] }
            let suggestion = linkedCandidate == nil && race.resultActivityId == nil
                ? suggest(for: race.distance, on: day, in: candidates.unlinked)
                : nil
            let result = linkedCandidate ?? suggestion
            let previousBest = bestByDistance.filter { isSameDistance($0.distance, race.distance) }.map(\.seconds).min()
            let isPR = result.map { candidate in
                candidate.garminPR || previousBest.map { candidate.seconds < $0 } == true
            } ?? false
            if let result, linkedCandidate != nil {
                bestByDistance.append((race.distance, result.seconds))
            }
            let splits = result.map { splitsFor(activityId: $0.activityId, context: context, race: race) } ?? []
            summaries[race.id] = CompletedRaceSummary(
                info: info,
                resultSeconds: result?.seconds,
                resultActivityId: result?.activityId,
                resultIsSuggestion: suggestion != nil,
                eveSeconds: race.frozenTargetSeconds,
                isPR: isPR && linkedCandidate != nil,
                splits: splits,
                lesson: RacesText.lesson(resultSeconds: result?.seconds, goalSeconds: race.goalSeconds, eveSeconds: race.frozenTargetSeconds, splits: splits)
            )
        }

        let upcomingRows = upcomingRaces.map { race, day in
            RaceRowData(
                id: race.id,
                name: race.name,
                dateText: RacesText.dateText(day),
                distanceText: RacesText.distanceText(race.distance),
                priority: race.priorityLevel.rawValue,
                detailText: TodayText.countdown(days: today.days(until: day), priority: race.priorityLevel.rawValue),
                resultText: race.goalSeconds.map { "\(TodayConstants.goalPrefix) \(TodayText.goalClock($0))" },
                isPR: false,
                isUpcoming: true
            )
        }
        let completedRows = pastRaces.reversed().map { race, day in
            let summary = summaries[race.id]
            return RaceRowData(
                id: race.id,
                name: race.name,
                dateText: RacesText.dateText(day),
                distanceText: RacesText.distanceText(race.distance),
                priority: race.priorityLevel.rawValue,
                detailText: summary?.resultVsGoalText.map { "\($0) \(C.goalLabel)" },
                resultText: summary?.resultSeconds.map(WorkoutFormat.clock) ?? C.noResult,
                isPR: summary?.isPR ?? false,
                isUpcoming: false
            )
        }
        return RaceListLoad(upcoming: upcomingRows, completed: completedRows, summaries: summaries)
    }

    nonisolated static func info(_ race: RaceRecord, day: Day) -> RaceInfo {
        RaceInfo(
            id: race.id, name: race.name, day: day, distance: race.distance, goalSeconds: race.goalSeconds,
            priority: race.priorityLevel, city: race.city, startTime: race.startTime
        )
    }

    nonisolated private static func resultCandidates(
        context: ModelContext, days: Set<Day>, linked: Set<Int64>
    ) -> (byId: [Int64: RaceResultCandidate], unlinked: [RaceResultCandidate]) {
        let ids = Array(linked)
        var records = (try? context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { ids.contains($0.activityId) }))) ?? []
        for day in days {
            let lower = day.chartDate
            let upper = day.adding(days: 1).chartDate
            records += (try? context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= lower && $0.start < upper }))) ?? []
        }
        records = records.filter { ActivityTypeKey.isRun($0.typeKey) }
        let candidates = records.compactMap { record -> RaceResultCandidate? in
            guard let seconds = record.duration, seconds > 0, let distance = record.distance, distance > 0 else { return nil }
            let day = record.localDay.flatMap(Day.init(iso:)) ?? Day.today(now: record.start)
            return RaceResultCandidate(activityId: record.activityId, day: day, distance: distance, seconds: seconds, garminPR: record.pr == true)
        }
        return (
            Dictionary(candidates.map { ($0.activityId, $0) }, uniquingKeysWith: { first, _ in first }),
            candidates.filter { !linked.contains($0.activityId) }
        )
    }

    nonisolated private static func suggest(for distance: Double, on day: Day, in candidates: [RaceResultCandidate]) -> RaceResultCandidate? {
        candidates
            .filter { $0.day == day && distance > 0 && abs($0.distance - distance) / distance <= C.resultDistanceTolerance }
            .min { abs($0.distance - distance) < abs($1.distance - distance) }
    }

    nonisolated private static func isSameDistance(_ a: Double, _ b: Double) -> Bool {
        b > 0 && abs(a - b) / b <= C.sameDistanceTolerance
    }

    nonisolated private static func splitsFor(activityId: Int64, context: ModelContext, race: RaceRecord) -> [RaceSplit] {
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == activityId })
        descriptor.fetchLimit = 1
        guard let data = (try? context.fetch(descriptor))?.first?.samplesData,
              let samples = try? JSONDecoder().decode([FITSample].self, from: data)
        else { return [] }
        let planned = race.frozenTargetSeconds.map {
            paceStrategy(goalSeconds: $0, distance: race.distance, profile: race.gpxData.flatMap { try? gpxProfile($0) }, manual: race.manualPaces)
        } ?? []
        return kilometerSplits(samples, zones: nil).enumerated().compactMap { index, block in
            guard block.distance > 0 else { return nil }
            return RaceSplit(
                index: index,
                distance: block.distance,
                pace: block.seconds / (block.distance / C.metersPerKm),
                planned: planned.first { $0.index == index }?.pace
            )
        }
    }
}
