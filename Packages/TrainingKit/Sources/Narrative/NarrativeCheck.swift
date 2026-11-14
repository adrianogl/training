import Foundation
import Metrics
import WorkoutAnalysis

enum NarrativeCheck {
    static func matches(
        _ sentence: String, template: String, words: [String], anyOf: [String] = [], forbidden: [String] = [], wholeWords: Bool = false
    ) -> Bool {
        let lowered = sentence.lowercased()
        let tokens = Set(lowered.split { !$0.isLetter }.map(String.init))
        let hasWord: (String) -> Bool = { wholeWords ? tokens.contains($0) : lowered.contains($0) }
        return !sentence.isEmpty
            && !NarrativeConstants.forbiddenFragments.contains { sentence.contains($0) }
            && numbers(in: sentence) == numbers(in: template)
            && words.allSatisfy(hasWord)
            && (anyOf.isEmpty || anyOf.contains(where: hasWord))
            && !forbidden.contains { tokens.contains($0) }
    }

    static func words(_ verdict: ReadinessVerdict) -> [String] {
        InsightNarrativeConstants.readinessRequiredWords[verdict] ?? []
    }

    static func forbidden(_ verdict: ReadinessVerdict) -> [String] {
        InsightNarrativeConstants.readinessForbiddenWords[verdict] ?? []
    }

    static func words(_ facts: OverallFacts) -> [String] {
        switch facts.verdict {
        case .better: InsightNarrativeConstants.betterWords
        case .worse: InsightNarrativeConstants.worseWords
        case .stable: [InsightNarrativeConstants.stableWord]
        }
    }

    static func forbidden(_ facts: OverallFacts) -> [String] {
        var forbidden: [String]
        switch facts.verdict {
        case .better: forbidden = InsightNarrativeConstants.worseWords
        case .worse: forbidden = InsightNarrativeConstants.betterWords
        case .stable: forbidden = [InsightNarrativeConstants.betterWords[0], InsightNarrativeConstants.worseWords[0]]
        }
        if let gap = facts.goalGapSeconds, gap != 0 {
            forbidden += [InsightNarrativeConstants.aboveGoalWord, InsightNarrativeConstants.belowGoalWord]
        }
        return forbidden
    }

    static func words(_ finding: Finding, blocks: [WorkoutBlock]) -> [String] {
        let status = NarrativeFormat.status(finding, blocks: blocks)
        switch finding.kind {
        case .blockOffTarget:
            switch status {
            case .aboveTarget: return [NarrativeConstants.aboveWord]
            case .belowTarget: return [NarrativeConstants.belowWord]
            case .slower: return [NarrativeConstants.slowerWord]
            case .faster: return [NarrativeConstants.fasterWord]
            default: return [NarrativeConstants.offTargetWord]
            }
        case .stepIncomplete:
            let state = status == .notExecuted ? NarrativeConstants.notExecutedWord : NarrativeConstants.notCompletedWord
            return [NarrativeConstants.negationWord, state]
        default:
            return []
        }
    }

    static func words(_ evolution: EvolutionFacts) -> [String] {
        let pace: String
        if abs(evolution.paceDelta) < NarrativeConstants.paceDeltaThreshold {
            pace = NarrativeConstants.samePaceWord
        } else {
            pace = evolution.paceDelta < 0 ? NarrativeConstants.fasterWord : NarrativeConstants.slowerWord
        }
        guard let heartRateDelta = evolution.heartRateDelta else { return [pace] }
        if abs(heartRateDelta) < NarrativeConstants.heartRateDeltaThreshold {
            return [pace, NarrativeConstants.equalWord]
        }
        return [pace, heartRateDelta < 0 ? NarrativeConstants.lowerWord : NarrativeConstants.higherWord]
    }

    static func numbers(in text: String) -> [String] {
        text.matches(of: /\d+/).map { String($0.output) }.sorted()
    }
}
