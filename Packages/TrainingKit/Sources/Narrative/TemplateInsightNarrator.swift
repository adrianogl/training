import Foundation
import Metrics
import WorkoutAnalysis

public struct TemplateInsightNarrator: InsightNarrator {
    public init() {}

    public func readinessSentence(_ breakdown: ReadinessBreakdown, verdict: ReadinessVerdict) async -> String {
        Self.readinessSentence(breakdown, verdict: verdict)
    }

    public func overallSentence(_ facts: OverallFacts) async -> String {
        Self.overallSentence(facts)
    }

    public static func readinessSentence(_ breakdown: ReadinessBreakdown, verdict: ReadinessVerdict) -> String {
        typealias Constants = InsightNarrativeConstants
        let phrase = Constants.verdictPhrases[verdict] ?? ""
        let head = "\(Constants.readinessPrefix) \(breakdown.score)\(Constants.separator)\(phrase)"
        let top = breakdown.factors
            .compactMap { factor in factor.points.map { (factor.component, $0) } }
            .filter { $0.1 != 0 }
            .sorted { abs($0.1) > abs($1.1) }
            .prefix(Constants.topFactorCount)
        guard let first = top.first else { return head + "." }
        var text = "\(head). \(capitalized(name(first.0))) \(direction(first.1)) \(Constants.normalSuffix)"
        if top.count > 1, let second = top.last {
            text += ", \(name(second.0)) \(direction(second.1))"
        }
        return text + "."
    }

    public static func overallSentence(_ facts: OverallFacts) -> String {
        typealias Constants = InsightNarrativeConstants
        var text: String
        switch facts.verdict {
        case .better: text = String(format: Constants.overallBetter, facts.improved, facts.total)
        case .stable: text = Constants.overallStable
        case .worse: text = String(format: Constants.overallWorse, facts.worsened, facts.total)
        }
        if let gap = facts.goalGapSeconds {
            text += String(format: Constants.goalGapSuffix, WorkoutFormat.clock(gap))
        }
        return text
    }

    private static func name(_ component: ReadinessComponent) -> String {
        InsightNarrativeConstants.componentNames[component] ?? component.rawValue
    }

    private static func direction(_ points: Double) -> String {
        points > 0 ? InsightNarrativeConstants.aboveNormal : InsightNarrativeConstants.belowNormal
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

public func morningNotificationText(_ breakdown: ReadinessBreakdown, verdict: ReadinessVerdict) -> String {
    TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
}
