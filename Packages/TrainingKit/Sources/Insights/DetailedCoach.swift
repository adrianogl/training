import Foundation
import Narrative

private typealias C = DetailedCoachConstants
private typealias T = DetailedCoachText

public enum DetailedCoach {
    public static func sections(for analysis: DetailedAnalysis) -> [DetailedCoachSection] {
        let facts: [DetailedCoachPart: [String]] = [
            .workout: workoutFacts(analysis),
            .context: contextFacts(analysis),
            .history: [DetailedFindingKind.startPace, .readiness, .weekLoad].compactMap { analysis.finding($0)?.text },
            .positive: analysis.findings.filter { $0.tone == .good && $0.kind != .completion }.map(\.text),
            .next: analysis.recommendations.map { String(format: T.recommendation, $0.title, $0.reason) },
        ]
        return DetailedCoachPart.allCases.compactMap { part in
            facts[part].flatMap { $0.isEmpty ? nil : DetailedCoachSection(part: part, facts: $0) }
        }
    }

    public static func generate(_ section: DetailedCoachSection) async -> String? {
        await CoachFeedback.rewrite(facts: section.facts, instructions: C.instructions(for: section.part), limits: C.limits(for: section.part))
    }

    public static func generate(_ section: DetailedCoachSection, generator: any FeedbackGenerator) async -> String? {
        await CoachFeedback.rewrite(
            facts: section.facts, instructions: C.instructions(for: section.part), limits: C.limits(for: section.part), generator: generator
        )
    }

    private static func workoutFacts(_ analysis: DetailedAnalysis) -> [String] {
        var facts = [analysis.finding(.completion)?.text].compactMap { $0 }
        let paces = analysis.splits.map(\.paceSeconds)
        if let mean = average(paces) {
            facts.append(String(format: T.paceAverage, DetailedFormat.pace(mean), paces.count))
        }
        if let fade = analysis.fadeKm, fade > 1, let low = paces.prefix(fade - 1).min(), let high = paces.prefix(fade - 1).max(),
           let after = average(Array(paces.dropFirst(fade - 1))) {
            let lowText = DetailedFormat.pace(low)
            let highText = DetailedFormat.pace(high)
            facts.append(lowText == highText ? String(format: T.stableSingle, fade - 1, lowText) : String(format: T.stableRange, fade - 1, lowText, highText))
            facts.append(String(format: T.afterFade, fade, DetailedFormat.pace(after)))
        }
        let heartRates = analysis.splits.compactMap(\.heartRate)
        if let first = heartRates.first, let last = heartRates.last, heartRates.count > 1 {
            facts.append(String(format: T.heartRateRange, DetailedFormat.whole(first), DetailedFormat.whole(last)))
        }
        facts += [DetailedFindingKind.fadeKm, .hrDrift, .pauses, .repsConsistency].compactMap { analysis.finding($0)?.text }
        return facts + elevationFacts(analysis.splits)
    }

    private static func elevationFacts(_ splits: [DetailedSplit]) -> [String] {
        let marked = splits.filter { abs($0.paceSeconds - $0.levelPace) >= C.elevationEffectSeconds }
        return marked.prefix(T.maxElevationFacts).map { split in
            let uphill = split.paceSeconds > split.levelPace
            return String(
                format: uphill ? T.climbKm : T.descentKm,
                split.km, DetailedFormat.whole(uphill ? split.climb : split.descent),
                DetailedFormat.pace(split.paceSeconds), DetailedFormat.pace(split.levelPace)
            )
        }
    }

    private static func contextFacts(_ analysis: DetailedAnalysis) -> [String] {
        guard !analysis.similar.isEmpty else { return [] }
        let kpis = analysis.kpis
        var facts = [String(format: T.comparedWith, analysis.similar.count, analysis.windowDays)]
        if let percent = kpis.completionPercent, let mean = kpis.completionAverage {
            facts.append(String(format: T.completionVersus, DetailedFormat.whole(percent), DetailedFormat.whole(mean)))
        }
        if let fade = kpis.fadeKm, let mean = kpis.fadeKmAverage {
            facts.append(String(format: T.fadeVersus, fade, DetailedFormat.whole(mean)))
        }
        if let drift = kpis.driftPercent, let mean = kpis.driftAverage {
            facts.append(String(format: T.driftVersus, DetailedFormat.whole(drift), DetailedFormat.whole(mean)))
        }
        return facts
    }
}
