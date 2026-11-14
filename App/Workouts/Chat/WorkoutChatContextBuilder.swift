import Foundation
import Storage
import WorkoutAnalysis

enum WorkoutChatContextBuilder {
    private typealias C = WorkoutChatContextConstants

    static func context(
        summary: WorkoutSummary,
        score: Int?,
        analysis: WorkoutAnalysisSummary,
        blocks: [WorkoutBlock],
        comparison: [ComparisonRow],
        daily: DailyRecord?,
        hasPrescription: Bool
    ) -> WorkoutChatContext {
        var facts = [
            "\(summary.title), \(summary.dateText).",
            [summary.distanceText.map { "\($0) km" }, summary.durationText, summary.paceText.map { "pace médio \($0)" }, summary.averageHeartRateText.map { "FC média \($0) bpm" }]
                .compactMap { $0 }.joined(separator: ", ") + ".",
        ]
        if let score { facts.append(String(format: C.scoreFormat, score)) }
        facts += analysis.coachFacts
        return WorkoutChatContext(
            title: summary.title,
            facts: facts.joined(separator: "\n"),
            blockLines: blocks.enumerated().map { index, block in
                let name = BlockNaming.tableLabel(block)
                let pace = block.avgSpeed.flatMap { WorkoutListModel.paceClock(metersPerSecond: $0) }.map { "pace \($0)/km" }
                let heart = block.avgHeartRate.map { "FC \($0) bpm" }
                let status = C.statuses[block.status] ?? ""
                return "\(index + 1). \([name.title, name.detail].compactMap { $0 }.joined(separator: " ")): " + [pace, heart, status].compactMap { $0 }.joined(separator: ", ")
            },
            similarLines: comparison.map { row in
                "\(row.dateText): " + [row.paceText.map { "pace \($0)" }, row.heartRateText.map { "FC \($0) bpm" }, row.inTargetText.map { "\($0) no alvo" }]
                    .compactMap { $0 }.joined(separator: ", ")
            },
            dayLine: daily.map(dayLine),
            suggestions: blocks.contains { $0.label.hasPrefix(WorkoutDetailConstants.repeatLabelPrefix) }
                ? WorkoutChatConstants.suggestionsIntervals
                : WorkoutChatConstants.suggestionsContinuous
        )
    }

    private static func dayLine(_ record: DailyRecord) -> String {
        var parts: [String] = []
        if let readiness = record.readinessScore { parts.append(String(format: C.readinessFormat, readiness)) }
        if let sleep = record.sleepScore { parts.append(String(format: C.sleepFormat, sleep)) }
        if let hrv = record.hrvLastNight {
            var text = String(format: C.hrvFormat, Int(hrv.rounded()))
            if let low = record.hrvBalancedLow, let high = record.hrvBalancedUpper {
                text += String(format: C.hrvBaseFormat, Int(low.rounded()), Int(high.rounded()))
            }
            parts.append(text)
        }
        if let resting = record.restingHR { parts.append(String(format: C.restingFormat, resting)) }
        return parts.isEmpty ? C.noDay : parts.joined(separator: ", ") + "."
    }
}

