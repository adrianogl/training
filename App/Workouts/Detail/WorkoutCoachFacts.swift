import Foundation
import WorkoutAnalysis

@MainActor
enum WorkoutCoachFacts {
    private typealias C = WorkoutCoachFactsConstants

    static func facts(_ model: WorkoutDetailModel, goals: [WorkoutGoalEntry], plan: PlannedBriefing?) -> [String] {
        [
            score(model),
            effect(model.trainingEffect),
            plan.flatMap(planFact),
            model.weather.map { plain(RunWeatherText.summary($0, pace: model.summary?.paceSeconds)) },
            load(model.summary),
            model.evolutionText.map { String(format: C.similarFormat, $0) },
            model.readinessScore.map { String(format: C.readinessFormat, $0) },
            model.performanceCondition.map { String(format: C.conditionFormat, $0 > 0 ? "+\($0)" : "\($0)") },
            week(model),
            model.daysSinceHard.map(hard),
        ].compactMap { $0 } + goals.map(goalFact)
    }

    private static func week(_ model: WorkoutDetailModel) -> String? {
        guard let kilometers = model.weekKilometers, kilometers > 0 else { return nil }
        let text = TodayText.decimal(kilometers, fractionDigits: 1)
        let goal = UserDefaults.standard.integer(forKey: AppConstants.weeklyGoalDefaultsKey)
        return goal > 0 ? String(format: C.weekGoalFormat, text, goal) : String(format: C.weekFormat, text)
    }

    private static func hard(_ days: Int) -> String {
        switch days {
        case 0: C.hardSameDayFormat
        case 1: C.hardOneFormat
        default: String(format: C.hardFormat, days)
        }
    }

    private static func plain(_ text: String) -> String {
        C.invisibleSpacing.reduce(text) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    private static func score(_ model: WorkoutDetailModel) -> String? {
        guard let score = model.score, !model.scoreRows.isEmpty else { return nil }
        let parts = model.scoreRows.filter(\.isIncluded).map {
            String(format: C.scorePartFormat, $0.name.lowercased(), Int($0.points.rounded()), Int($0.maximum.rounded()))
        }
        return String(format: C.scoreFormat, score.value, parts.joined(separator: C.scorePartSeparator))
    }

    private static func effect(_ effect: TrainingEffectData?) -> String? {
        guard let effect else { return nil }
        let parts = [
            effect.aerobic.map { String(format: C.effectAerobicFormat, TodayText.decimal($0, fractionDigits: 1), level($0)) },
            effect.anaerobic.map { String(format: C.effectAnaerobicFormat, TodayText.decimal($0, fractionDigits: 1), level($0)) },
            effect.highZoneSeconds.map { String(format: C.effectHighZonesFormat, WorkoutFormat.clock($0)) },
        ].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        let label = effect.label.flatMap { WorkoutDetailConstants.effectLabels[$0] }
        return String(format: C.effectFormat, ([label].compactMap { $0 } + parts).joined(separator: C.effectSeparator))
    }

    private static func level(_ value: Double) -> String {
        let levels = WorkoutDetailConstants.effectLevels
        return levels[min(max(Int(value), 0), levels.count - 1)]
    }

    private static func load(_ summary: WorkoutSummary?) -> String? {
        guard let summary, let load = summary.loadText, summary.loadCaption != TrainingLoadConstants.plain else { return nil }
        return String(format: C.loadFormat, load, summary.loadCaption)
    }

    private static func planFact(_ plan: PlannedBriefing) -> String? {
        let rows = plan.comparison
        guard !rows.isEmpty else { return nil }
        let items = rows.map { String(format: C.planItemFormat, $0.label, $0.planned, $0.done) }
        return String(format: C.planFormat, rows.filter(\.ok).count, rows.count, items.joined(separator: C.planSeparator))
    }

    private static func goalFact(_ goal: WorkoutGoalEntry) -> String {
        String(format: C.goalFormat, goal.title, goal.status, goal.lines.joined(separator: " "))
    }
}
