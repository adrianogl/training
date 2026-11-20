import Foundation
import Insights
import Narrative
import Observation
import Storage
import SwiftData
import WorkoutAnalysis

@MainActor @Observable final class DetailedAnalysisModel {
    private(set) var analysis: DetailedAnalysis?
    private(set) var title = ""
    private(set) var dateText = ""
    private(set) var sections: [DetailedCoachSection] = []
    private(set) var states: [DetailedCoachPart: CoachPartState] = [:]
    private(set) var isLoaded = false

    private let store = GeneratedTextStore()
    private typealias C = DetailedScreenConstants

    init(activityId: Int64, goalEntries: [WorkoutGoalEntry], extraFacts: [String] = [], context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        defer { isLoaded = true }
        guard let record = records.first(where: { $0.activityId == activityId }) else { return }
        let daily = (try? context.fetch(FetchDescriptor<DailyRecord>())) ?? []
        let goals = (try? activeGoals(in: context)) ?? []
        let notes = goalEntries.map { DetailedGoalNote(title: $0.title, status: $0.status, isMet: $0.good, lines: $0.lines) }
        analysis = detailedAnalysis(
            record: record,
            history: records,
            daily: daily,
            goals: notes,
            longGoalKm: goals.filter { $0.goalKind == .continuousLong }.map(\.distanceKm).min(),
            raceGoalKms: goals.filter { $0.goalKind == .time }.map(\.distanceKm)
        )
        let name = record.displayTitle
        title = (record.distance ?? 0) > 0 ? "\(name) · \(WorkoutFormat.kilometers(record.distance ?? 0)) km" : name
        dateText = record.start.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutFormat.locale))
        sections = (analysis.map(DetailedCoach.sections(for:)) ?? []).map { section in
            section.part == .workout ? DetailedCoachSection(part: section.part, facts: section.facts + extraFacts) : section
        }
        states = Dictionary(uniqueKeysWithValues: sections.map { ($0.part, CoachPartState.pending) })
    }

    func generateCoach() async {
        for section in sections where states[section.part] == .pending {
            let key = [section.part.rawValue] + section.facts
            if let cached = store.text(for: key) {
                states[section.part] = .generated(cached)
                continue
            }
            guard CoachFeedback.isAvailable, let text = await DetailedCoach.generate(section) else {
                states[section.part] = .fallback(section.fallback)
                continue
            }
            store.save(text, for: key)
            states[section.part] = .generated(text)
        }
    }

    var comparedText: String {
        guard let analysis else { return "" }
        let compared = analysis.similar.isEmpty
            ? String(format: C.noSimilar, analysis.windowDays)
            : String(format: C.comparedFormat, analysis.similar.count, analysis.windowDays)
        return dateText + " · " + compared
    }

    var sourcesText: String? {
        guard let analysis, !analysis.similar.isEmpty else { return nil }
        return String(format: C.sourcesFormat, analysis.similar.count, analysis.readinessDays, analysis.windowDays)
    }

    var tiles: [DetailedKPITile] {
        guard let analysis else { return [] }
        let kpis = analysis.kpis
        var tiles: [DetailedKPITile] = []
        if let percent = kpis.completionPercent {
            tiles.append(DetailedKPITile(
                id: 0, value: Self.percent(percent),
                caption: analysis.finding(.completion) == nil ? C.kpiCompletionReference : C.kpiCompletionPlanned,
                average: kpis.completionAverage.map { Self.percent($0) },
                isWorse: kpis.completionAverage.map { percent < $0 } ?? false
            ))
        }
        if analysis.kind != .intervals, !analysis.splits.isEmpty {
            tiles.append(DetailedKPITile(
                id: 1, value: kpis.fadeKm.map { String(format: C.kmFormat, $0) } ?? "—",
                caption: kpis.fadeKm == nil ? C.kpiNoFade : C.kpiFade,
                average: kpis.fadeKmAverage.map { String(format: C.kmFormat, Int($0.rounded())) },
                isWorse: kpis.fadeKm.flatMap { fade in kpis.fadeKmAverage.map { Double(fade) < $0 } } ?? false
            ))
        }
        if let drift = kpis.driftPercent {
            tiles.append(DetailedKPITile(
                id: 2, value: Self.signedPercent(drift), caption: C.kpiDrift,
                average: kpis.driftAverage.map { Self.signedPercent($0) },
                isWorse: kpis.driftAverage.map { drift > $0 } ?? false
            ))
        }
        return tiles
    }

    var bars: [SimilarBar] {
        guard let analysis else { return [] }
        let rows = analysis.similar + [analysis.current]
        return rows.compactMap { run in
            run.percentOfDistance.map { percent in
                SimilarBar(
                    id: run.activityId,
                    label: run.activityId == analysis.current.activityId ? C.legendToday : run.start.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(WorkoutFormat.locale)),
                    percent: percent,
                    role: run.activityId == analysis.current.activityId ? .today : run.isClean ? .clean : run.isComplete ? .complete : .partial
                )
            }
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static func signedPercent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)%" : "\(rounded)%"
    }
}
