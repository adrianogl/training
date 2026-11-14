import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

enum EvolutionChatContextBuilder {
    private typealias C = EvolutionChatContextConstants

    static func context(
        verdictTitle: String,
        sentence: String,
        indicators: [IndicatorDumbbellData],
        outlook: RaceOutlook,
        countdownDays: Int?,
        cards: [MetricCardData],
        records: [PersonalRecord],
        zoneWeeks: [ZoneWeek]
    ) -> WorkoutChatContext {
        var facts = [verdictTitle + ".", sentence]
        facts += indicators.map { indicator in
            "\(indicator.name): \(indicator.todayText)"
                + (indicator.deltaText.map { String(format: C.deltaFormat, $0) } ?? "")
                + (indicator.goalText.map { String(format: C.goalFormat, $0) } ?? "") + "."
        }
        if let today = outlook.today { facts.append(String(format: C.predictionFormat, outlook.label, WorkoutFormat.clock(today))) }
        if let raceDay = outlook.raceDay { facts.append(String(format: C.raceDayFormat, WorkoutFormat.clock(raceDay.mid))) }
        if let goal = outlook.goalSeconds { facts.append(String(format: C.raceGoalFormat, WorkoutFormat.clock(goal))) }
        if let days = countdownDays { facts.append(String(format: C.countdownFormat, days)) }
        let order = EvolutionConstants.cardKinds
        return WorkoutChatContext(
            copy: WorkoutChatConstants.evolutionCopy,
            title: WorkoutChatConstants.evolutionTitle,
            facts: facts.filter { !$0.isEmpty }.joined(separator: "\n"),
            blockLines: cards.sorted { (order.firstIndex(of: $0.kind) ?? 0) < (order.firstIndex(of: $1.kind) ?? 0) }.map(metricLine),
            similarLines: records.map { record in
                String(format: C.recordFormat, record.label, WorkoutFormat.clock(record.seconds), record.date.formatted(.dateTime.day().month(.abbreviated).year().locale(WorkoutConstants.locale)))
            },
            dayLine: zoneWeeks.isEmpty ? nil : zoneWeeks.suffix(C.zoneWeeks).map(zoneLine).joined(separator: "\n"),
            suggestions: WorkoutChatConstants.suggestionsEvolution
        )
    }

    private static func metricLine(_ card: MetricCardData) -> String {
        let format = EvolutionConstants.metricFormats[card.kind]
        let value = { (number: Double?) in EvolutionText.value(number, format) }
        let stats = card.stats
        var parts = [
            String(format: C.currentFormat, value(stats.current)),
            String(format: C.averageFormat, value(stats.average)),
            String(format: C.rangeFormat, value(stats.minimum), value(stats.maximum)),
        ]
        if let change = EvolutionText.delta(stats.change, format) { parts.append(String(format: C.changeFormat, change)) }
        return (EvolutionConstants.metricNames[card.kind] ?? card.kind.rawValue) + ": " + parts.joined(separator: ", ")
    }

    private static func zoneLine(_ week: ZoneWeek) -> String {
        let zones = week.seconds.enumerated().map { index, seconds in "Z\(index + 1) \(Int((seconds / 60).rounded())) min" }
        return String(format: C.zoneWeekFormat, week.start.day, week.start.month) + zones.joined(separator: ", ")
    }
}
