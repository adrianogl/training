import WorkoutAnalysis

enum NarrativeCheck {
    static func matches(_ sentence: String, template: String, words: [String]) -> Bool {
        let lowered = sentence.lowercased()
        return !sentence.isEmpty
            && !NarrativeConstants.forbiddenFragments.contains { sentence.contains($0) }
            && numbers(in: sentence) == numbers(in: template)
            && words.allSatisfy { lowered.contains($0) }
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

    private static func numbers(in text: String) -> [String] {
        text.matches(of: /\d+/).map { String($0.output) }.sorted()
    }
}
